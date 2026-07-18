import '../util/hex.dart';
import '../util/json.dart';
import 'algorithm_registry.dart';

class ManifestFileRecord {
  const ManifestFileRecord({
    required this.path,
    required this.size,
    required this.digests,
    this.modifiedAt,
    this.mode,
    this.symlinkTarget,
    this.unstable = false,
    this.attempts = 1,
  });

  final String path;
  final int size;
  final DateTime? modifiedAt;
  final int? mode;
  final String? symlinkTarget;
  final Map<String, String> digests;
  final bool unstable;
  final int attempts;

  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'size': size,
        if (modifiedAt != null)
          'modifiedAt': modifiedAt!.toUtc().toIso8601String(),
        if (mode != null) 'mode': mode,
        if (symlinkTarget != null) 'symlinkTarget': symlinkTarget,
        if (unstable) 'unstable': true,
        if (attempts > 1) 'attempts': attempts,
        'digests': digests,
      };

  factory ManifestFileRecord.fromJson(Map<String, Object?> json) =>
      ManifestFileRecord(
        path: json['path']! as String,
        size: json['size']! as int,
        modifiedAt: json['modifiedAt'] == null
            ? null
            : DateTime.parse(json['modifiedAt']! as String),
        mode: json['mode'] as int?,
        symlinkTarget: json['symlinkTarget'] as String?,
        unstable: json['unstable'] as bool? ?? false,
        attempts: json['attempts'] as int? ?? 1,
        digests: (json['digests']! as Map).cast<String, String>(),
      );
}

class ManifestReadError {
  const ManifestReadError({
    required this.path,
    required this.code,
    required this.message,
  });

  final String path;
  final String code;
  final String message;

  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'code': code,
        'message': message,
      };

  factory ManifestReadError.fromJson(Map<String, Object?> json) =>
      ManifestReadError(
        path: json['path']! as String,
        code: json['code']! as String,
        message: json['message']! as String,
      );
}

class CentraManifest {
  CentraManifest({
    required this.id,
    required this.generatedAt,
    required this.toolVersion,
    required this.profileId,
    required this.profileName,
    required this.projectKind,
    required this.source,
    required this.algorithms,
    required this.includePatterns,
    required this.excludePatterns,
    required Iterable<ManifestFileRecord> files,
    required this.errors,
    required this.totalBytes,
    this.directoriesVisited = 0,
    this.skipped = 0,
    this.unstableFiles = 0,
    this.transferredBytes = 0,
    this.durationMilliseconds = 0,
    this.baseline,
  }) : files = (files.toList()
          ..sort((left, right) => left.path.compareTo(right.path)));

  final String id;
  final DateTime generatedAt;
  final String toolVersion;
  final String profileId;
  final String profileName;
  final String projectKind;
  final Map<String, Object?> source;
  final List<HashAlgorithmDescriptor> algorithms;
  final List<String> includePatterns;
  final List<String> excludePatterns;
  final List<ManifestFileRecord> files;
  final List<ManifestReadError> errors;
  final int totalBytes;
  final int directoriesVisited;
  final int skipped;
  final int unstableFiles;
  final int transferredBytes;
  final int durationMilliseconds;
  final Map<String, Object?>? baseline;

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 'centra.manifest.v1',
        'id': id,
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'tool': <String, Object?>{
          'name': 'Centra',
          'version': toolVersion,
        },
        'profile': <String, Object?>{
          'id': profileId,
          'name': profileName,
          'projectKind': projectKind,
        },
        'source': source,
        'algorithms': algorithms
            .map((algorithm) => algorithm.toJson())
            .toList(growable: false),
        'policy': <String, Object?>{
          'includes': includePatterns,
          'excludes': excludePatterns,
        },
        'summary': <String, Object?>{
          'fileCount': files.length,
          'totalBytes': totalBytes,
          'readErrorCount': errors.length,
          'directoriesVisited': directoriesVisited,
          'skipped': skipped,
          'unstableFiles': unstableFiles,
          'transferredBytes': transferredBytes,
          'durationMilliseconds': durationMilliseconds,
        },
        if (baseline != null) 'baseline': baseline,
        'files': files.map((file) => file.toJson()).toList(growable: false),
        'errors': errors.map((error) => error.toJson()).toList(growable: false),
      };

  String encodeCanonical() => canonicalJson(toJson());

  String encodePretty() => prettyJson(toJson());

  factory CentraManifest.fromJson(Map<String, Object?> json) {
    if (json['schema'] != 'centra.manifest.v1') {
      throw FormatException('Unsupported manifest schema: ${json['schema']}');
    }
    final tool = (json['tool']! as Map).cast<String, Object?>();
    final profile = (json['profile']! as Map).cast<String, Object?>();
    final policy = (json['policy']! as Map).cast<String, Object?>();
    final summary = (json['summary']! as Map).cast<String, Object?>();
    return CentraManifest(
      id: json['id']! as String,
      generatedAt: DateTime.parse(json['generatedAt']! as String),
      toolVersion: tool['version']! as String,
      profileId: profile['id']! as String,
      profileName: profile['name']! as String,
      projectKind: profile['projectKind'] as String? ?? 'generic',
      source: (json['source']! as Map).cast<String, Object?>(),
      algorithms: (json['algorithms']! as List<Object?>)
          .map((value) => HashAlgorithmDescriptor.fromJson(
              (value! as Map).cast<String, Object?>()))
          .toList(growable: false),
      includePatterns: (policy['includes']! as List<Object?>).cast<String>(),
      excludePatterns: (policy['excludes']! as List<Object?>).cast<String>(),
      files: (json['files']! as List<Object?>)
          .map((value) => ManifestFileRecord.fromJson(
              (value! as Map).cast<String, Object?>()))
          .toList(growable: false),
      errors: (json['errors'] as List<Object?>? ?? const <Object?>[])
          .map((value) => ManifestReadError.fromJson(
              (value! as Map).cast<String, Object?>()))
          .toList(growable: false),
      totalBytes: summary['totalBytes']! as int,
      directoriesVisited: summary['directoriesVisited'] as int? ?? 0,
      skipped: summary['skipped'] as int? ?? 0,
      unstableFiles: summary['unstableFiles'] as int? ?? 0,
      transferredBytes: summary['transferredBytes'] as int? ?? 0,
      durationMilliseconds: summary['durationMilliseconds'] as int? ?? 0,
      baseline: json['baseline'] == null
          ? null
          : (json['baseline']! as Map).cast<String, Object?>(),
    );
  }
}

enum ManifestChangeType {
  added,
  removed,
  modified,
  metadata,
  unchanged,
}

class ManifestChange {
  const ManifestChange({
    required this.path,
    required this.type,
    required this.changedAlgorithms,
    this.before,
    this.after,
  });

  final String path;
  final ManifestChangeType type;
  final List<String> changedAlgorithms;
  final ManifestFileRecord? before;
  final ManifestFileRecord? after;

  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'type': type.name,
        'changedAlgorithms': changedAlgorithms,
        if (before != null) 'before': before!.toJson(),
        if (after != null) 'after': after!.toJson(),
      };
}

class ManifestDiff {
  const ManifestDiff(this.changes);

  final List<ManifestChange> changes;

  int count(ManifestChangeType type) =>
      changes.where((change) => change.type == type).length;

  bool get hasIntegrityChanges => changes.any(
        (change) =>
            change.type == ManifestChangeType.added ||
            change.type == ManifestChangeType.removed ||
            change.type == ManifestChangeType.modified,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'summary': <String, Object?>{
          for (final type in ManifestChangeType.values) type.name: count(type),
        },
        'changes':
            changes.map((change) => change.toJson()).toList(growable: false),
      };
}

class ManifestComparator {
  const ManifestComparator();

  ManifestDiff compare(CentraManifest before, CentraManifest after) {
    final beforeByPath = <String, ManifestFileRecord>{
      for (final file in before.files) file.path: file
    };
    final afterByPath = <String, ManifestFileRecord>{
      for (final file in after.files) file.path: file
    };
    final paths = <String>{...beforeByPath.keys, ...afterByPath.keys}.toList()
      ..sort();
    final changes = <ManifestChange>[];
    for (final path in paths) {
      final oldFile = beforeByPath[path];
      final newFile = afterByPath[path];
      if (oldFile == null) {
        changes.add(ManifestChange(
          path: path,
          type: ManifestChangeType.added,
          changedAlgorithms: newFile!.digests.keys.toList()..sort(),
          after: newFile,
        ));
        continue;
      }
      if (newFile == null) {
        changes.add(ManifestChange(
          path: path,
          type: ManifestChangeType.removed,
          changedAlgorithms: oldFile.digests.keys.toList()..sort(),
          before: oldFile,
        ));
        continue;
      }
      final algorithmIds = <String>{
        ...oldFile.digests.keys,
        ...newFile.digests.keys
      }.toList()
        ..sort();
      final changedAlgorithms = <String>[];
      for (final id in algorithmIds) {
        final left = oldFile.digests[id];
        final right = newFile.digests[id];
        if (left == null ||
            right == null ||
            !constantTimeHexEquals(left, right)) {
          changedAlgorithms.add(id);
        }
      }
      if (changedAlgorithms.isNotEmpty ||
          oldFile.size != newFile.size ||
          oldFile.symlinkTarget != newFile.symlinkTarget) {
        changes.add(ManifestChange(
          path: path,
          type: ManifestChangeType.modified,
          changedAlgorithms: changedAlgorithms,
          before: oldFile,
          after: newFile,
        ));
        continue;
      }
      final metadataChanged =
          oldFile.modifiedAt?.toUtc() != newFile.modifiedAt?.toUtc() ||
              oldFile.mode != newFile.mode;
      changes.add(ManifestChange(
        path: path,
        type: metadataChanged
            ? ManifestChangeType.metadata
            : ManifestChangeType.unchanged,
        changedAlgorithms: const <String>[],
        before: oldFile,
        after: newFile,
      ));
    }
    return ManifestDiff(changes);
  }
}
