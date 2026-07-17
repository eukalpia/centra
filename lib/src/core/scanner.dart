import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart';

import '../util/hex.dart';
import 'algorithm_registry.dart';
import 'manifest.dart';
import 'path_policy.dart';
import 'profile.dart';
import 'source.dart';
import 'ssh_connection.dart';

const centraVersion = '0.1.0';

class ScanProgress {
  const ScanProgress({
    required this.phase,
    required this.discovered,
    required this.completed,
    required this.totalBytes,
    this.currentPath,
  });

  final String phase;
  final int discovered;
  final int completed;
  final int totalBytes;
  final String? currentPath;
}

typedef ScanProgressCallback = void Function(ScanProgress progress);

class ScanResult {
  const ScanResult({required this.manifest, required this.duration});

  final CentraManifest manifest;
  final Duration duration;
}

class _InventoryEntry {
  const _InventoryEntry({
    required this.entity,
    required this.path,
    required this.isLink,
  });

  final FileSystemEntity entity;
  final String path;
  final bool isLink;
}

abstract interface class _HashAccumulator {
  void update(Uint8List bytes);
  String finish();
}

class _DigestAccumulator implements _HashAccumulator {
  _DigestAccumulator(this.digest);

  final Digest digest;

  @override
  void update(Uint8List bytes) => digest.update(bytes, 0, bytes.length);

  @override
  String finish() {
    final output = Uint8List(digest.digestSize);
    digest.doFinal(output, 0);
    return hexEncode(output);
  }
}

class _Crc32Accumulator implements _HashAccumulator {
  var _value = 0;

  @override
  void update(Uint8List bytes) => _value = getCrc32(bytes, _value);

  @override
  String finish() => _value.toUnsigned(32).toRadixString(16).padLeft(8, '0');
}

class _Adler32Accumulator implements _HashAccumulator {
  var _value = 1;

  @override
  void update(Uint8List bytes) => _value = getAdler32(bytes, _value);

  @override
  String finish() => _value.toUnsigned(32).toRadixString(16).padLeft(8, '0');
}

class IntegrityScanner {
  IntegrityScanner({
    SourceRegistry? sourceRegistry,
    CommandRunner commandRunner = const SystemCommandRunner(),
    DateTime Function()? clock,
    Random? random,
  })  : _sourceRegistry =
            sourceRegistry ?? SourceRegistry(runner: commandRunner),
        _commandRunner = commandRunner,
        _clock = clock ?? DateTime.now,
        _random = random ?? Random.secure();

  final SourceRegistry _sourceRegistry;
  final CommandRunner _commandRunner;
  final DateTime Function() _clock;
  final Random _random;

  Future<ScanResult> scan(
    CentraProfile profile, {
    ScanProgressCallback? onProgress,
    SshConnectionSecrets? sshSecrets,
  }) async {
    final validationErrors = profile.validate();
    if (validationErrors.isNotEmpty) {
      throw FormatException(validationErrors.join('\n'));
    }
    final stopwatch = Stopwatch()..start();
    final prepared = await _sourceRegistry
        .provider(profile.source.type)
        .prepare(profile.source, sshSecrets: sshSecrets);
    try {
      final registry = AlgorithmRegistry(
        customAlgorithms: profile.customAlgorithms,
      );
      final descriptors =
          profile.algorithmIds.map(registry.descriptor).toList(growable: false);
      final policy = PathPolicy(
        includes: profile.includePatterns,
        excludes: profile.excludePatterns,
        includeHiddenFiles: profile.includeHiddenFiles,
      );
      onProgress?.call(
        const ScanProgress(
          phase: 'inventory',
          discovered: 0,
          completed: 0,
          totalBytes: 0,
        ),
      );
      final inventory = await _inventory(
        prepared.directory,
        profile,
        policy,
        onProgress,
      );
      final files = <ManifestFileRecord>[];
      final errors = <ManifestReadError>[];
      var nextIndex = 0;
      var completed = 0;
      var totalBytes = 0;

      Future<void> worker() async {
        while (true) {
          _InventoryEntry? entry;
          if (nextIndex < inventory.length) {
            entry = inventory[nextIndex++];
          }
          if (entry == null) return;
          try {
            final record = await _hashEntry(
              entry: entry,
              profile: profile,
              registry: registry,
            );
            files.add(record);
            totalBytes += record.size;
          } on Object catch (error) {
            errors.add(
              ManifestReadError(
                path: entry.path,
                code: error.runtimeType.toString(),
                message: error.toString(),
              ),
            );
            if (profile.failOnReadError) rethrow;
          } finally {
            completed++;
            onProgress?.call(
              ScanProgress(
                phase: 'hashing',
                discovered: inventory.length,
                completed: completed,
                totalBytes: totalBytes,
                currentPath: entry.path,
              ),
            );
          }
        }
      }

      await Future.wait(
        List<Future<void>>.generate(profile.workerCount, (_) => worker()),
      );
      files.sort((left, right) => left.path.compareTo(right.path));
      errors.sort((left, right) => left.path.compareTo(right.path));
      final generatedAt = _clock().toUtc();
      final manifest = CentraManifest(
        id: _manifestId(generatedAt),
        generatedAt: generatedAt,
        toolVersion: centraVersion,
        profileId: profile.id,
        profileName: profile.name,
        projectKind: profile.projectKind,
        source: prepared.metadata,
        algorithms: descriptors,
        includePatterns: profile.includePatterns,
        excludePatterns: profile.excludePatterns,
        files: files,
        errors: errors,
        totalBytes: totalBytes,
      );
      onProgress?.call(
        ScanProgress(
          phase: 'complete',
          discovered: inventory.length,
          completed: completed,
          totalBytes: totalBytes,
        ),
      );
      stopwatch.stop();
      return ScanResult(manifest: manifest, duration: stopwatch.elapsed);
    } finally {
      await prepared.dispose();
    }
  }

  Future<List<_InventoryEntry>> _inventory(
    Directory root,
    CentraProfile profile,
    PathPolicy policy,
    ScanProgressCallback? onProgress,
  ) async {
    final entries = <_InventoryEntry>[];
    await for (final entity in root.list(
      recursive: true,
      followLinks: profile.symlinkPolicy == SymlinkPolicy.follow,
    )) {
      final relative = normalizeRelativePath(
        p.relative(entity.path, from: root.path),
      );
      if (!policy.allows(relative)) continue;
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.file) {
        entries.add(
          _InventoryEntry(
            entity: File(entity.path),
            path: relative,
            isLink: false,
          ),
        );
      } else if (type == FileSystemEntityType.link &&
          profile.symlinkPolicy == SymlinkPolicy.record) {
        entries.add(
          _InventoryEntry(
            entity: Link(entity.path),
            path: relative,
            isLink: true,
          ),
        );
      }
      if (entries.length % 250 == 0 && entries.isNotEmpty) {
        onProgress?.call(
          ScanProgress(
            phase: 'inventory',
            discovered: entries.length,
            completed: 0,
            totalBytes: 0,
            currentPath: relative,
          ),
        );
      }
    }
    entries.sort((left, right) => left.path.compareTo(right.path));
    return entries;
  }

  Future<ManifestFileRecord> _hashEntry({
    required _InventoryEntry entry,
    required CentraProfile profile,
    required AlgorithmRegistry registry,
  }) async {
    final stat = await entry.entity.stat();
    final accumulators = <String, _HashAccumulator>{};
    for (final id in profile.algorithmIds) {
      if (registry.custom(id) != null) continue;
      accumulators[id] = switch (id) {
        'crc32' => _Crc32Accumulator(),
        'adler32' => _Adler32Accumulator(),
        _ => _DigestAccumulator(registry.createDigest(id)),
      };
    }

    String? symlinkTarget;
    if (entry.isLink) {
      symlinkTarget = await (entry.entity as Link).target();
      final bytes = Uint8List.fromList(utf8.encode(symlinkTarget));
      for (final accumulator in accumulators.values) {
        accumulator.update(bytes);
      }
    } else {
      await for (final chunk in (entry.entity as File).openRead()) {
        final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        for (final accumulator in accumulators.values) {
          accumulator.update(bytes);
        }
      }
    }

    final digests = <String, String>{
      for (final entry in accumulators.entries) entry.key: entry.value.finish(),
    };
    for (final id in profile.algorithmIds) {
      final custom = registry.custom(id);
      if (custom != null) {
        digests[id] = await _runCustom(custom, entry.entity.path);
      }
    }
    return ManifestFileRecord(
      path: entry.path,
      size: entry.isLink ? utf8.encode(symlinkTarget!).length : stat.size,
      modifiedAt: profile.source.type == SourceType.ssh
          ? null
          : profile.captureModificationTimes
              ? stat.modified.toUtc()
              : null,
      mode: profile.source.type == SourceType.ssh
          ? null
          : profile.capturePermissions
              ? stat.mode
              : null,
      symlinkTarget: symlinkTarget,
      digests: Map<String, String>.fromEntries(
        profile.algorithmIds.map(
          (id) => MapEntry<String, String>(id, digests[id]!),
        ),
      ),
    );
  }

  Future<String> _runCustom(
    CustomHashAlgorithm algorithm,
    String filePath,
  ) async {
    final arguments = algorithm.arguments
        .map((argument) => argument.replaceAll('{file}', filePath))
        .toList(growable: false);
    final result = await _commandRunner.run(
      algorithm.executable,
      arguments,
      timeout: Duration(seconds: algorithm.timeoutSeconds),
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        algorithm.executable,
        arguments,
        result.stderrText,
        result.exitCode,
      );
    }
    final match = RegExp(
      algorithm.outputPattern,
      multiLine: true,
    ).firstMatch(result.stdoutText);
    if (match == null || algorithm.outputGroup > match.groupCount) {
      throw FormatException(
        'Custom algorithm ${algorithm.id} output did not match its configured pattern.',
      );
    }
    final value = match.group(algorithm.outputGroup)!.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(value)) {
      throw FormatException(
        'Custom algorithm ${algorithm.id} returned non-hexadecimal output.',
      );
    }
    if (algorithm.outputBits > 0 && value.length * 4 != algorithm.outputBits) {
      throw FormatException(
        'Custom algorithm ${algorithm.id} returned ${value.length * 4} bits; expected ${algorithm.outputBits}.',
      );
    }
    return value;
  }

  String _manifestId(DateTime generatedAt) {
    final randomPart = List<int>.generate(8, (_) => _random.nextInt(256));
    final timestamp = generatedAt
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 14);
    return '$timestamp-${hexEncode(randomPart)}';
  }
}
