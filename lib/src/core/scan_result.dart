import 'algorithm_registry.dart';
import 'manifest.dart';
import 'profile.dart';
import 'scan_control.dart';

class ScanResult {
  const ScanResult({
    required this.manifest,
    required this.duration,
    required this.summary,
    required this.estimate,
  });

  final CentraManifest manifest;
  final Duration duration;
  final ScanSummary summary;
  final ScanEstimate estimate;
}

class PreparedScan {
  PreparedScan({
    required this.estimate,
    required Future<ScanResult> Function({
      CentraManifest? baseline,
      VerificationMode? verificationMode,
      Map<String, Object?>? baselineMetadata,
    }) execute,
    required Future<void> Function() dispose,
  })  : _execute = execute,
        _dispose = dispose;

  final ScanEstimate estimate;
  final Future<ScanResult> Function({
    CentraManifest? baseline,
    VerificationMode? verificationMode,
    Map<String, Object?>? baselineMetadata,
  }) _execute;
  final Future<void> Function() _dispose;
  var _started = false;
  var _disposed = false;

  Future<ScanResult> run({
    CentraManifest? baseline,
    VerificationMode? verificationMode,
    Map<String, Object?>? baselineMetadata,
  }) async {
    if (_disposed) throw StateError('Prepared scan is already disposed.');
    if (_started) throw StateError('Prepared scan can only run once.');
    _started = true;
    try {
      return await _execute(
        baseline: baseline,
        verificationMode: verificationMode,
        baselineMetadata: baselineMetadata,
      );
    } finally {
      await dispose();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _dispose();
  }
}

ScanResult buildScanResult({
  required String toolVersion,
  required String manifestId,
  required DateTime generatedAt,
  required CentraProfile profile,
  required Map<String, Object?> source,
  required List<HashAlgorithmDescriptor> descriptors,
  required List<ManifestFileRecord> records,
  required List<ScanIssue> issues,
  required int directories,
  required int skipped,
  required int unstableFiles,
  required int transferredBytes,
  required Duration duration,
  required ScanEstimate estimate,
  required Map<String, Object?>? baselineMetadata,
  required ScanProgressCallback? onProgress,
}) {
  records.sort((left, right) => left.path.compareTo(right.path));
  final readIssues = issues
      .where(
        (issue) => issue.code != 'unstable_file' &&
            issue.code != 'one_file_system_best_effort',
      )
      .toList(growable: false);
  final errors = readIssues
      .map(
        (issue) => ManifestReadError(
          path: issue.path,
          code: issue.code,
          message: issue.message,
        ),
      )
      .toList(growable: false)
    ..sort((left, right) => left.path.compareTo(right.path));
  final totalBytes = records.fold<int>(0, (sum, record) => sum + record.size);
  final manifest = CentraManifest(
    id: manifestId,
    generatedAt: generatedAt,
    toolVersion: toolVersion,
    profileId: profile.id,
    profileName: profile.name,
    projectKind: profile.projectKind,
    source: source,
    algorithms: descriptors,
    includePatterns: profile.includePatterns,
    excludePatterns: profile.excludePatterns,
    files: records,
    errors: errors,
    totalBytes: totalBytes,
    directoriesVisited: directories,
    skipped: skipped,
    unstableFiles: unstableFiles,
    transferredBytes: transferredBytes,
    durationMilliseconds: duration.inMilliseconds,
    baseline: baselineMetadata,
  );
  final summary = ScanSummary(
    filesHashed: records.length,
    directoriesVisited: directories,
    skipped: skipped,
    readErrors: readIssues.length,
    unstableFiles: unstableFiles,
    transferredBytes: transferredBytes,
    duration: duration,
    issues: List<ScanIssue>.unmodifiable(issues),
  );
  onProgress?.call(
    ScanProgress(
      phase: 'complete',
      discovered: records.length,
      completed: records.length,
      totalBytes: totalBytes,
      directories: directories,
      skipped: skipped,
      readErrors: readIssues.length,
      unstableFiles: unstableFiles,
      transferredBytes: transferredBytes,
      expectedBytes: estimate.bytes,
      elapsed: duration,
    ),
  );
  return ScanResult(
    manifest: manifest,
    duration: duration,
    summary: summary,
    estimate: estimate,
  );
}
