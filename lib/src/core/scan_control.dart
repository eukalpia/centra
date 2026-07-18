import 'dart:async';

/// Determines how an approved manifest is verified.
enum VerificationMode {
  full,
  fast,
}

extension VerificationModeName on VerificationMode {
  String get wireName => name;

  static VerificationMode parse(String value) =>
      VerificationMode.values.firstWhere(
        (mode) => mode.wireName == value,
        orElse: () =>
            throw FormatException('Unknown verification mode: $value'),
      );
}

/// Determines how file read failures are handled.
enum ReadErrorPolicy {
  stop,
  continueScan,
  retry,
}

extension ReadErrorPolicyName on ReadErrorPolicy {
  String get wireName => switch (this) {
        ReadErrorPolicy.stop => 'stop',
        ReadErrorPolicy.continueScan => 'continue',
        ReadErrorPolicy.retry => 'retry',
      };

  static ReadErrorPolicy parse(String value) => switch (value) {
        'stop' => ReadErrorPolicy.stop,
        'continue' => ReadErrorPolicy.continueScan,
        'retry' => ReadErrorPolicy.retry,
        _ => throw FormatException('Unknown read error policy: $value'),
      };
}

class ScanCancelledException implements Exception {
  const ScanCancelledException([this.message = 'Scan cancelled.']);

  final String message;

  @override
  String toString() => message;
}

typedef ScanCancellationListener = void Function();

/// Cooperative cancellation shared by inventory, transfer, hashing and output.
class ScanCancellationToken {
  final Completer<void> _cancelledCompleter = Completer<void>();
  final Set<ScanCancellationListener> _listeners = <ScanCancellationListener>{};
  var _cancelled = false;

  bool get isCancelled => _cancelled;
  Future<void> get whenCancelled => _cancelledCompleter.future;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_cancelledCompleter.isCompleted) {
      _cancelledCompleter.complete();
    }
    final listeners = List<ScanCancellationListener>.from(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      try {
        listener();
      } on Object {
        // Cancellation cleanup is best effort. The active operation still sees
        // the token and fails with ScanCancelledException.
      }
    }
  }

  void throwIfCancelled() {
    if (_cancelled) throw const ScanCancelledException();
  }

  void Function() addListener(ScanCancellationListener listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  Future<T> race<T>(Future<T> operation) {
    throwIfCancelled();
    return Future.any<T>(<Future<T>>[
      operation,
      whenCancelled.then<T>((_) => throw const ScanCancelledException()),
    ]);
  }
}

class ScanLimits {
  const ScanLimits({
    this.fileTimeoutSeconds = 120,
    this.maximumFileBytes = 0,
    this.maximumTotalBytes = 0,
    this.maximumFiles = 2000000,
    this.maximumDepth = 256,
    this.oneFileSystem = false,
  });

  /// Zero means unlimited.
  final int maximumFileBytes;

  /// Zero means unlimited.
  final int maximumTotalBytes;
  final int maximumFiles;
  final int maximumDepth;
  final int fileTimeoutSeconds;
  final bool oneFileSystem;

  List<String> validate() {
    final errors = <String>[];
    if (fileTimeoutSeconds < 1 || fileTimeoutSeconds > 86400) {
      errors.add('File timeout must be between 1 and 86400 seconds.');
    }
    if (maximumFileBytes < 0) {
      errors.add('Maximum file size cannot be negative.');
    }
    if (maximumTotalBytes < 0) {
      errors.add('Maximum total size cannot be negative.');
    }
    if (maximumFiles < 1 || maximumFiles > 100000000) {
      errors.add('Maximum file count must be between 1 and 100000000.');
    }
    if (maximumDepth < 1 || maximumDepth > 4096) {
      errors.add('Maximum directory depth must be between 1 and 4096.');
    }
    return errors;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'fileTimeoutSeconds': fileTimeoutSeconds,
        'maximumFileBytes': maximumFileBytes,
        'maximumTotalBytes': maximumTotalBytes,
        'maximumFiles': maximumFiles,
        'maximumDepth': maximumDepth,
        'oneFileSystem': oneFileSystem,
      };

  factory ScanLimits.fromJson(Map<String, Object?> json) => ScanLimits(
        fileTimeoutSeconds: json['fileTimeoutSeconds'] as int? ?? 120,
        maximumFileBytes: json['maximumFileBytes'] as int? ?? 0,
        maximumTotalBytes: json['maximumTotalBytes'] as int? ?? 0,
        maximumFiles: json['maximumFiles'] as int? ?? 2000000,
        maximumDepth: json['maximumDepth'] as int? ?? 256,
        oneFileSystem: json['oneFileSystem'] as bool? ?? false,
      );
}

class ExclusionEstimate {
  const ExclusionEstimate({
    required this.pattern,
    required this.files,
    required this.bytes,
  });

  final String pattern;
  final int files;
  final int bytes;

  Map<String, Object?> toJson() => <String, Object?>{
        'pattern': pattern,
        'files': files,
        'bytes': bytes,
      };
}

class ScanEstimate {
  const ScanEstimate({
    required this.files,
    required this.directories,
    required this.bytes,
    required this.skipped,
    required this.exclusions,
    this.minimumDuration,
    this.maximumDuration,
  });

  final int files;
  final int directories;
  final int bytes;
  final int skipped;
  final List<ExclusionEstimate> exclusions;
  final Duration? minimumDuration;
  final Duration? maximumDuration;

  Map<String, Object?> toJson() => <String, Object?>{
        'files': files,
        'directories': directories,
        'bytes': bytes,
        'skipped': skipped,
        'exclusions': exclusions
            .map((exclusion) => exclusion.toJson())
            .toList(growable: false),
        if (minimumDuration != null)
          'minimumDurationMilliseconds': minimumDuration!.inMilliseconds,
        if (maximumDuration != null)
          'maximumDurationMilliseconds': maximumDuration!.inMilliseconds,
      };
}

class ScanProgress {
  const ScanProgress({
    required this.phase,
    required this.discovered,
    required this.completed,
    required this.totalBytes,
    this.currentPath,
    this.directories = 0,
    this.skipped = 0,
    this.readErrors = 0,
    this.unstableFiles = 0,
    this.transferredBytes = 0,
    this.expectedBytes = 0,
    this.elapsed = Duration.zero,
    this.message,
  });

  final String phase;
  final int discovered;
  final int completed;
  final int totalBytes;
  final String? currentPath;
  final int directories;
  final int skipped;
  final int readErrors;
  final int unstableFiles;
  final int transferredBytes;
  final int expectedBytes;
  final Duration elapsed;
  final String? message;

  double? get fraction {
    if (discovered <= 0) return null;
    return (completed / discovered).clamp(0, 1);
  }

  double? get bytesPerSecond {
    if (elapsed.inMilliseconds < 1000 || transferredBytes <= 0) return null;
    return transferredBytes / (elapsed.inMilliseconds / 1000);
  }

  Duration? get eta {
    final speed = bytesPerSecond;
    if (speed == null || expectedBytes <= transferredBytes) return null;
    final seconds = (expectedBytes - transferredBytes) / speed;
    if (!seconds.isFinite || seconds < 0) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  ScanProgress copyWith({
    String? phase,
    int? discovered,
    int? completed,
    int? totalBytes,
    String? currentPath,
    int? directories,
    int? skipped,
    int? readErrors,
    int? unstableFiles,
    int? transferredBytes,
    int? expectedBytes,
    Duration? elapsed,
    String? message,
  }) =>
      ScanProgress(
        phase: phase ?? this.phase,
        discovered: discovered ?? this.discovered,
        completed: completed ?? this.completed,
        totalBytes: totalBytes ?? this.totalBytes,
        currentPath: currentPath ?? this.currentPath,
        directories: directories ?? this.directories,
        skipped: skipped ?? this.skipped,
        readErrors: readErrors ?? this.readErrors,
        unstableFiles: unstableFiles ?? this.unstableFiles,
        transferredBytes: transferredBytes ?? this.transferredBytes,
        expectedBytes: expectedBytes ?? this.expectedBytes,
        elapsed: elapsed ?? this.elapsed,
        message: message ?? this.message,
      );
}

typedef ScanProgressCallback = void Function(ScanProgress progress);

class ScanIssue {
  const ScanIssue({
    required this.path,
    required this.code,
    required this.message,
    this.attempts = 1,
  });

  final String path;
  final String code;
  final String message;
  final int attempts;

  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'code': code,
        'message': message,
        'attempts': attempts,
      };
}

class ScanSummary {
  const ScanSummary({
    required this.filesHashed,
    required this.directoriesVisited,
    required this.skipped,
    required this.readErrors,
    required this.unstableFiles,
    required this.transferredBytes,
    required this.duration,
    required this.issues,
  });

  final int filesHashed;
  final int directoriesVisited;
  final int skipped;
  final int readErrors;
  final int unstableFiles;
  final int transferredBytes;
  final Duration duration;
  final List<ScanIssue> issues;

  Map<String, Object?> toJson() => <String, Object?>{
        'filesHashed': filesHashed,
        'directoriesVisited': directoriesVisited,
        'skipped': skipped,
        'readErrors': readErrors,
        'unstableFiles': unstableFiles,
        'transferredBytes': transferredBytes,
        'durationMilliseconds': duration.inMilliseconds,
        'issues': issues.map((issue) => issue.toJson()).toList(growable: false),
      };
}
