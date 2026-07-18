import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'algorithm_registry.dart';
import 'hashing.dart';
import 'manifest.dart';
import 'path_policy.dart';
import 'profile.dart';
import 'scan_control.dart';

class LocalInventoryEntry {
  const LocalInventoryEntry({
    required this.entity,
    required this.path,
    required this.isLink,
    required this.size,
    required this.modifiedAt,
    required this.mode,
    this.symlinkTarget,
  });

  final FileSystemEntity entity;
  final String path;
  final bool isLink;
  final int size;
  final DateTime? modifiedAt;
  final int? mode;
  final String? symlinkTarget;
}

class LocalScanPlan {
  const LocalScanPlan({
    required this.entries,
    required this.directories,
    required this.skipped,
    required this.totalBytes,
    required this.exclusions,
    required this.issues,
  });

  final List<LocalInventoryEntry> entries;
  final int directories;
  final int skipped;
  final int totalBytes;
  final List<ExclusionEstimate> exclusions;
  final List<ScanIssue> issues;

  ScanEstimate estimate(
          {Duration? minimumDuration, Duration? maximumDuration}) =>
      ScanEstimate(
        files: entries.length,
        directories: directories,
        bytes: totalBytes,
        skipped: skipped,
        exclusions: exclusions,
        minimumDuration: minimumDuration,
        maximumDuration: maximumDuration,
      );
}

class LocalScanExecution {
  const LocalScanExecution({
    required this.records,
    required this.issues,
    required this.transferredBytes,
    required this.unstableFiles,
  });

  final List<ManifestFileRecord> records;
  final List<ScanIssue> issues;
  final int transferredBytes;
  final int unstableFiles;
}

typedef CustomHashRunner = Future<String> Function(
  CustomHashAlgorithm algorithm,
  String filePath,
  ScanCancellationToken token,
);

class LocalScanEngine {
  const LocalScanEngine();

  Future<LocalScanPlan> inventory(
    Directory root, {
    required CentraProfile profile,
    required PathPolicy pathPolicy,
    required ScanCancellationToken cancellationToken,
    ScanProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final entries = <LocalInventoryEntry>[];
    final issues = <ScanIssue>[];
    final exclusionCounts = <String, ({int files, int bytes})>{};
    var directories = 0;
    var skipped = 0;
    var totalBytes = 0;
    var observed = 0;

    void countExclusion(String pattern, int bytes) {
      final current = exclusionCounts[pattern];
      exclusionCounts[pattern] = (
        files: (current?.files ?? 0) + 1,
        bytes: (current?.bytes ?? 0) + bytes,
      );
      skipped++;
    }

    Future<List<FileSystemEntity>?> listDirectory(
      Directory directory,
      String relativePath,
    ) async {
      final attempts = profile.effectiveReadErrorPolicy == ReadErrorPolicy.retry
          ? profile.readRetryCount + 1
          : 1;
      Object? lastError;
      for (var attempt = 1; attempt <= attempts; attempt++) {
        cancellationToken.throwIfCancelled();
        try {
          return await cancellationToken.race(
            directory
                .list(followLinks: false)
                .toList()
                .timeout(Duration(seconds: profile.limits.fileTimeoutSeconds)),
          );
        } on ScanCancelledException {
          rethrow;
        } on Object catch (error) {
          lastError = error;
          if (attempt < attempts) continue;
        }
      }
      if (profile.effectiveReadErrorPolicy == ReadErrorPolicy.stop) {
        Error.throwWithStackTrace(lastError!, StackTrace.current);
      }
      issues.add(ScanIssue(
        path: relativePath,
        code: lastError.runtimeType.toString(),
        message: lastError.toString(),
        attempts: attempts,
      ));
      return null;
    }

    Future<void> walk(
      Directory directory,
      String relativeDirectory,
      int depth, {
      String? inheritedExclusion,
    }) async {
      cancellationToken.throwIfCancelled();
      if (depth > profile.limits.maximumDepth) {
        throw FileSystemException(
          'Directory depth exceeds the configured safety limit.',
          directory.path,
        );
      }
      final children = await listDirectory(directory, relativeDirectory);
      if (children == null) return;
      for (final entity in children) {
        cancellationToken.throwIfCancelled();
        observed++;
        if (observed > profile.limits.maximumFiles) {
          throw FileSystemException(
            'Source exceeds the configured entry limit.',
            root.path,
          );
        }
        final relative = normalizeRelativePath(
          p.relative(entity.path, from: root.path),
        );
        final type =
            await FileSystemEntity.type(entity.path, followLinks: false);
        final directoryExclusion = inheritedExclusion ??
            pathPolicy.matchingExclusion(relative, directory: true);
        if (type == FileSystemEntityType.directory) {
          if (directoryExclusion == null) directories++;
          await walk(
            Directory(entity.path),
            relative,
            depth + 1,
            inheritedExclusion: directoryExclusion,
          );
          continue;
        }
        final stat = await entity.stat();
        final exclusion =
            inheritedExclusion ?? pathPolicy.matchingExclusion(relative);
        if (exclusion != null || !pathPolicy.allows(relative)) {
          countExclusion(exclusion ?? '<policy>', stat.size);
          continue;
        }
        if (type == FileSystemEntityType.link) {
          if (profile.symlinkPolicy == SymlinkPolicy.skip) {
            countExclusion('<symlink>', stat.size);
            continue;
          }
          final target = await Link(entity.path).target();
          final size = utf8.encode(target).length;
          entries.add(LocalInventoryEntry(
            entity: Link(entity.path),
            path: relative,
            isLink: true,
            size: size,
            modifiedAt:
                profile.captureModificationTimes ? stat.modified.toUtc() : null,
            mode: profile.capturePermissions ? stat.mode : null,
            symlinkTarget: target,
          ));
          totalBytes += size;
          continue;
        }
        if (type != FileSystemEntityType.file) {
          countExclusion('<special-file>', stat.size);
          continue;
        }
        if (profile.limits.maximumFileBytes > 0 &&
            stat.size > profile.limits.maximumFileBytes) {
          countExclusion('<maximum-file-size>', stat.size);
          issues.add(ScanIssue(
            path: relative,
            code: 'maximum_file_size',
            message: 'File exceeds the configured maximum file size.',
          ));
          continue;
        }
        if (profile.limits.maximumTotalBytes > 0 &&
            totalBytes + stat.size > profile.limits.maximumTotalBytes) {
          throw FileSystemException(
            'Source exceeds the configured total byte limit.',
            entity.path,
          );
        }
        entries.add(LocalInventoryEntry(
          entity: File(entity.path),
          path: relative,
          isLink: false,
          size: stat.size,
          modifiedAt:
              profile.captureModificationTimes ? stat.modified.toUtc() : null,
          mode: profile.capturePermissions ? stat.mode : null,
        ));
        totalBytes += stat.size;
        if (observed % 250 == 0) {
          onProgress?.call(ScanProgress(
            phase: 'inventory',
            discovered: entries.length,
            completed: entries.length,
            totalBytes: totalBytes,
            currentPath: relative,
            directories: directories,
            skipped: skipped,
            readErrors: issues.length,
            expectedBytes: totalBytes,
            elapsed: stopwatch.elapsed,
          ));
        }
      }
    }

    await walk(root, '', 0);
    entries.sort((left, right) => left.path.compareTo(right.path));
    final exclusions = exclusionCounts.entries
        .map((entry) => ExclusionEstimate(
              pattern: entry.key,
              files: entry.value.files,
              bytes: entry.value.bytes,
            ))
        .toList(growable: false)
      ..sort((left, right) => right.bytes.compareTo(left.bytes));
    return LocalScanPlan(
      entries: entries,
      directories: directories,
      skipped: skipped,
      totalBytes: totalBytes,
      exclusions: exclusions,
      issues: issues,
    );
  }

  Future<LocalScanExecution> execute(
    LocalScanPlan plan, {
    required CentraProfile profile,
    required AlgorithmRegistry registry,
    required CustomHashRunner runCustom,
    required ScanCancellationToken cancellationToken,
    required VerificationMode verificationMode,
    CentraManifest? baseline,
    ScanProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final baselineByPath = <String, ManifestFileRecord>{
      for (final record in baseline?.files ?? const <ManifestFileRecord>[])
        record.path: record,
    };
    final records = <ManifestFileRecord>[];
    final issues = <ScanIssue>[...plan.issues];
    final pending = <LocalInventoryEntry>[];
    for (final entry in plan.entries) {
      final approved = baselineByPath[entry.path];
      if (verificationMode == VerificationMode.fast &&
          approved != null &&
          _canReuse(entry, approved, profile.algorithmIds)) {
        records.add(ManifestFileRecord(
          path: entry.path,
          size: entry.size,
          modifiedAt: entry.modifiedAt,
          mode: entry.mode,
          symlinkTarget: entry.symlinkTarget,
          digests: Map<String, String>.from(approved.digests),
        ));
      } else {
        pending.add(entry);
      }
    }
    var nextIndex = 0;
    var completed = 0;
    var bytesRead = 0;
    var unstableFiles = 0;
    Object? firstError;
    StackTrace? firstStackTrace;
    final expectedBytes =
        pending.fold<int>(0, (sum, value) => sum + value.size);

    Future<void> worker() async {
      while (firstError == null) {
        cancellationToken.throwIfCancelled();
        final index = nextIndex++;
        if (index >= pending.length) return;
        final entry = pending[index];
        try {
          final outcome = await _hashEntry(
            entry: entry,
            profile: profile,
            registry: registry,
            runCustom: runCustom,
            cancellationToken: cancellationToken,
          );
          if (outcome.record != null) records.add(outcome.record!);
          if (outcome.issue != null) issues.add(outcome.issue!);
          bytesRead += outcome.bytesRead;
          if (outcome.unstable) unstableFiles++;
        } on ScanCancelledException {
          rethrow;
        } on Object catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
          return;
        } finally {
          completed++;
          onProgress?.call(ScanProgress(
            phase: 'hashing',
            discovered: pending.length,
            completed: completed,
            totalBytes: bytesRead,
            currentPath: entry.path,
            directories: plan.directories,
            skipped: plan.skipped,
            readErrors:
                issues.where((issue) => issue.code != 'unstable_file').length,
            unstableFiles: unstableFiles,
            transferredBytes: bytesRead,
            expectedBytes: expectedBytes,
            elapsed: stopwatch.elapsed,
          ));
        }
      }
    }

    await Future.wait(
      List<Future<void>>.generate(profile.workerCount, (_) => worker()),
    );
    cancellationToken.throwIfCancelled();
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
    records.sort((left, right) => left.path.compareTo(right.path));
    return LocalScanExecution(
      records: records,
      issues: issues,
      transferredBytes: bytesRead,
      unstableFiles: unstableFiles,
    );
  }

  Future<_LocalHashOutcome> _hashEntry({
    required LocalInventoryEntry entry,
    required CentraProfile profile,
    required AlgorithmRegistry registry,
    required CustomHashRunner runCustom,
    required ScanCancellationToken cancellationToken,
  }) async {
    final maximumReadAttempts =
        profile.effectiveReadErrorPolicy == ReadErrorPolicy.retry
            ? profile.readRetryCount + 1
            : 1;
    Object? lastError;
    for (var readAttempt = 1;
        readAttempt <= maximumReadAttempts;
        readAttempt++) {
      var unstableAttempt = 0;
      while (true) {
        cancellationToken.throwIfCancelled();
        try {
          final before = await entry.entity.stat();
          final pipeline = StreamingHashPipeline(
            registry: registry,
            algorithmIds: profile.algorithmIds,
          );
          String? symlinkTarget = entry.symlinkTarget;
          if (entry.isLink) {
            symlinkTarget ??= await (entry.entity as Link).target();
            pipeline.add(utf8.encode(symlinkTarget));
          } else {
            final operation = () async {
              await for (final chunk in (entry.entity as File).openRead()) {
                cancellationToken.throwIfCancelled();
                pipeline.add(chunk);
              }
            }();
            await cancellationToken.race(
              operation.timeout(
                Duration(seconds: profile.limits.fileTimeoutSeconds),
              ),
            );
          }
          final after = await entry.entity.stat();
          final unstable = before.size != after.size ||
              before.modified.toUtc() != after.modified.toUtc() ||
              before.mode != after.mode;
          if (unstable && unstableAttempt < profile.unstableRetryCount) {
            unstableAttempt++;
            continue;
          }
          final digests = pipeline.finish();
          for (final id in profile.algorithmIds) {
            final custom = registry.custom(id);
            if (custom != null) {
              digests[id] = await runCustom(
                custom,
                entry.entity.path,
                cancellationToken,
              );
            }
          }
          final record = ManifestFileRecord(
            path: entry.path,
            size: pipeline.bytes,
            modifiedAt: profile.captureModificationTimes
                ? after.modified.toUtc()
                : null,
            mode: profile.capturePermissions ? after.mode : null,
            symlinkTarget: symlinkTarget,
            digests: _orderedDigests(profile.algorithmIds, digests),
            unstable: unstable,
            attempts: readAttempt + unstableAttempt,
          );
          return _LocalHashOutcome(
            record: record,
            issue: unstable
                ? ScanIssue(
                    path: entry.path,
                    code: 'unstable_file',
                    message: 'File changed while it was being read.',
                    attempts: readAttempt + unstableAttempt,
                  )
                : null,
            bytesRead: pipeline.bytes,
            unstable: unstable,
          );
        } on ScanCancelledException {
          rethrow;
        } on Object catch (error) {
          lastError = error;
          break;
        }
      }
      if (readAttempt < maximumReadAttempts) continue;
    }
    if (profile.effectiveReadErrorPolicy == ReadErrorPolicy.stop) {
      Error.throwWithStackTrace(lastError!, StackTrace.current);
    }
    return _LocalHashOutcome(
      issue: ScanIssue(
        path: entry.path,
        code: lastError.runtimeType.toString(),
        message: lastError.toString(),
        attempts: maximumReadAttempts,
      ),
      bytesRead: 0,
      unstable: false,
    );
  }

  bool _canReuse(
    LocalInventoryEntry entry,
    ManifestFileRecord approved,
    List<String> algorithms,
  ) =>
      algorithms.every(approved.digests.containsKey) &&
      approved.size == entry.size &&
      approved.modifiedAt?.toUtc() == entry.modifiedAt?.toUtc() &&
      approved.mode == entry.mode &&
      approved.symlinkTarget == entry.symlinkTarget &&
      !approved.unstable;

  Map<String, String> _orderedDigests(
    List<String> ids,
    Map<String, String> values,
  ) =>
      Map<String, String>.fromEntries(
        ids.map((id) => MapEntry<String, String>(id, values[id]!)),
      );
}

class _LocalHashOutcome {
  const _LocalHashOutcome({
    this.record,
    this.issue,
    required this.bytesRead,
    required this.unstable,
  });

  final ManifestFileRecord? record;
  final ScanIssue? issue;
  final int bytesRead;
  final bool unstable;
}
