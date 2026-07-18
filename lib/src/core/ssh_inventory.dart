import 'scan_control.dart';

class SshRemoteEntry {
  const SshRemoteEntry({
    required this.path,
    required this.remotePath,
    required this.size,
    required this.modifiedAt,
    required this.mode,
    required this.isLink,
    this.symlinkTarget,
  });

  final String path;
  final String remotePath;
  final int size;
  final DateTime? modifiedAt;
  final int? mode;
  final bool isLink;
  final String? symlinkTarget;
}

class SshInventoryResult {
  const SshInventoryResult({
    required this.root,
    required this.entries,
    required this.directories,
    required this.skipped,
    required this.totalBytes,
    required this.exclusions,
    required this.issues,
  });

  final String root;
  final List<SshRemoteEntry> entries;
  final int directories;
  final int skipped;
  final int totalBytes;
  final List<ExclusionEstimate> exclusions;
  final List<ScanIssue> issues;

  ScanEstimate toEstimate({
    Duration? minimumDuration,
    Duration? maximumDuration,
  }) =>
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

class SshStreamedFileResult<T> {
  const SshStreamedFileResult({
    required this.entry,
    required this.value,
    required this.bytesRead,
    required this.unstable,
    required this.attempts,
    required this.beforeSize,
    required this.afterSize,
    required this.beforeModifiedAt,
    required this.afterModifiedAt,
  });

  final SshRemoteEntry entry;
  final T value;
  final int bytesRead;
  final bool unstable;
  final int attempts;
  final int? beforeSize;
  final int? afterSize;
  final DateTime? beforeModifiedAt;
  final DateTime? afterModifiedAt;
}

class SshStreamBatch<T> {
  const SshStreamBatch({
    required this.files,
    required this.issues,
    required this.transferredBytes,
    required this.unstableFiles,
  });

  final List<SshStreamedFileResult<T>> files;
  final List<ScanIssue> issues;
  final int transferredBytes;
  final int unstableFiles;
}
