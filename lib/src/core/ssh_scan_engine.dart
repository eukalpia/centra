import 'dart:io';

import 'package:path/path.dart' as p;

import 'algorithm_registry.dart';
import 'hashing.dart';
import 'manifest.dart';
import 'profile.dart';
import 'scan_control.dart';
import 'ssh_connection.dart';
import 'ssh_inventory.dart';

class SshScanExecution {
  const SshScanExecution({
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

typedef SshCustomHashRunner = Future<String> Function(
  CustomHashAlgorithm algorithm,
  String filePath,
  ScanCancellationToken token,
);

class SshScanEngine {
  const SshScanEngine();

  Future<SshScanExecution> execute(
    SshConnection connection,
    SshInventoryResult inventory, {
    required CentraProfile profile,
    required AlgorithmRegistry registry,
    required SshCustomHashRunner runCustom,
    required ScanCancellationToken cancellationToken,
    required VerificationMode verificationMode,
    CentraManifest? baseline,
    ScanProgressCallback? onProgress,
  }) async {
    final baselineByPath = <String, ManifestFileRecord>{
      for (final record in baseline?.files ?? const <ManifestFileRecord>[])
        record.path: record,
    };
    final records = <ManifestFileRecord>[];
    final pending = <SshRemoteEntry>[];
    for (final entry in inventory.entries) {
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

    final customAlgorithms = profile.algorithmIds
        .map(registry.custom)
        .whereType<CustomHashAlgorithm>()
        .toList(growable: false);
    final temporary = customAlgorithms.isEmpty
        ? null
        : await Directory.systemTemp.createTemp('centra-stream-');
    try {
      final batch = await connection.streamRemoteFiles<ManifestFileRecord>(
        pending,
        workerCount: profile.workerCount,
        fileTimeout: Duration(seconds: profile.limits.fileTimeoutSeconds),
        readErrorPolicy: profile.effectiveReadErrorPolicy,
        readRetryCount: profile.readRetryCount,
        unstableRetryCount: profile.unstableRetryCount,
        cancellationToken: cancellationToken,
        onProgress: onProgress,
        consume: (entry, stream, attempt) async {
          cancellationToken.throwIfCancelled();
          final pipeline = StreamingHashPipeline(
            registry: registry,
            algorithmIds: profile.algorithmIds,
          );
          File? mirrorFile;
          IOSink? mirror;
          if (temporary != null) {
            mirrorFile = File(p.join(
              temporary.path,
              '${entry.path.hashCode.toUnsigned(32)}-$attempt.bin',
            ));
            mirror = mirrorFile.openWrite();
          }
          try {
            await for (final chunk in stream) {
              cancellationToken.throwIfCancelled();
              pipeline.add(chunk);
              mirror?.add(chunk);
            }
            await mirror?.flush();
            await mirror?.close();
            mirror = null;
            final digests = pipeline.finish();
            if (mirrorFile != null) {
              for (final algorithm in customAlgorithms) {
                digests[algorithm.id] = await runCustom(
                  algorithm,
                  mirrorFile.path,
                  cancellationToken,
                );
              }
            }
            return ManifestFileRecord(
              path: entry.path,
              size: pipeline.bytes,
              modifiedAt:
                  profile.captureModificationTimes ? entry.modifiedAt : null,
              mode: profile.capturePermissions ? entry.mode : null,
              symlinkTarget: entry.symlinkTarget,
              digests: _orderedDigests(profile.algorithmIds, digests),
              attempts: attempt,
            );
          } finally {
            await mirror?.close();
            if (mirrorFile != null && await mirrorFile.exists()) {
              await mirrorFile.delete();
            }
          }
        },
      );
      for (final result in batch.files) {
        final value = result.value;
        records.add(ManifestFileRecord(
          path: value.path,
          size: value.size,
          modifiedAt: value.modifiedAt,
          mode: value.mode,
          symlinkTarget: value.symlinkTarget,
          digests: value.digests,
          unstable: result.unstable,
          attempts: result.attempts,
        ));
      }
      records.sort((left, right) => left.path.compareTo(right.path));
      final issues = <ScanIssue>[...inventory.issues, ...batch.issues];
      if (profile.limits.oneFileSystem) {
        issues.add(const ScanIssue(
          path: '/',
          code: 'one_file_system_best_effort',
          message:
              'Standard SFTP does not expose a portable filesystem device ID; virtual filesystems are excluded during root scans.',
        ));
      }
      return SshScanExecution(
        records: records,
        issues: issues,
        transferredBytes: batch.transferredBytes,
        unstableFiles: batch.unstableFiles,
      );
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    }
  }

  bool _canReuse(
    SshRemoteEntry entry,
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
