import 'algorithm_registry.dart';

enum SourceType { local, ssh, dockerContainer, dockerImage, dockerCompose }

extension SourceTypeName on SourceType {
  String get wireName => switch (this) {
    SourceType.local => 'local',
    SourceType.ssh => 'ssh',
    SourceType.dockerContainer => 'docker-container',
    SourceType.dockerImage => 'docker-image',
    SourceType.dockerCompose => 'docker-compose',
  };

  static SourceType parse(String value) => SourceType.values.firstWhere(
    (type) => type.wireName == value,
    orElse: () => throw FormatException('Unknown source type: $value'),
  );
}

enum SymlinkPolicy { skip, record, follow }

extension SymlinkPolicyName on SymlinkPolicy {
  String get wireName => name;

  static SymlinkPolicy parse(String value) => SymlinkPolicy.values.firstWhere(
    (policy) => policy.name == value,
    orElse: () => throw FormatException('Unknown symlink policy: $value'),
  );
}

class SourceConfig {
  const SourceConfig({
    required this.type,
    required this.root,
    this.host,
    this.user,
    this.port = 22,
    this.identityFile,
    this.container,
    this.image,
    this.service,
    this.composeFile,
    this.dockerContext,
  });

  final SourceType type;
  final String root;
  final String? host;
  final String? user;
  final int port;
  final String? identityFile;
  final String? container;
  final String? image;
  final String? service;
  final String? composeFile;
  final String? dockerContext;

  List<String> validate() {
    final errors = <String>[];
    if (root.trim().isEmpty) errors.add('Source root is required.');
    switch (type) {
      case SourceType.local:
        break;
      case SourceType.ssh:
        if ((host ?? '').trim().isEmpty) errors.add('SSH host is required.');
        if ((user ?? '').trim().isEmpty) errors.add('SSH user is required.');
        if (port < 1 || port > 65535)
          errors.add('SSH port must be between 1 and 65535.');
        break;
      case SourceType.dockerContainer:
        if ((container ?? '').trim().isEmpty)
          errors.add('Docker container is required.');
        break;
      case SourceType.dockerImage:
        if ((image ?? '').trim().isEmpty)
          errors.add('Docker image is required.');
        break;
      case SourceType.dockerCompose:
        if ((service ?? '').trim().isEmpty)
          errors.add('Compose service is required.');
        break;
    }
    return errors;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.wireName,
    'root': root,
    'port': port,
    if (host != null) 'host': host,
    if (user != null) 'user': user,
    if (identityFile != null) 'identityFile': identityFile,
    if (container != null) 'container': container,
    if (image != null) 'image': image,
    if (service != null) 'service': service,
    if (composeFile != null) 'composeFile': composeFile,
    if (dockerContext != null) 'dockerContext': dockerContext,
  };

  factory SourceConfig.fromJson(Map<String, Object?> json) => SourceConfig(
    type: SourceTypeName.parse(json['type']! as String),
    root: json['root']! as String,
    host: json['host'] as String?,
    user: json['user'] as String?,
    port: json['port'] as int? ?? 22,
    identityFile: json['identityFile'] as String?,
    container: json['container'] as String?,
    image: json['image'] as String?,
    service: json['service'] as String?,
    composeFile: json['composeFile'] as String?,
    dockerContext: json['dockerContext'] as String?,
  );
}

class OutputConfig {
  const OutputConfig({
    required this.directory,
    required this.writeCanonicalJson,
    required this.writeCompatibilityText,
    required this.createZip,
    required this.requireZipPassword,
    required this.includeMetadataReport,
  });

  final String directory;
  final bool writeCanonicalJson;
  final bool writeCompatibilityText;
  final bool createZip;
  final bool requireZipPassword;
  final bool includeMetadataReport;

  List<String> validate() {
    final errors = <String>[];
    if (directory.trim().isEmpty) errors.add('Output directory is required.');
    if (!writeCanonicalJson &&
        !writeCompatibilityText &&
        !includeMetadataReport) {
      errors.add('Select at least one output format.');
    }
    if (requireZipPassword && !createZip) {
      errors.add('ZIP password requirement needs ZIP output.');
    }
    return errors;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'directory': directory,
    'writeCanonicalJson': writeCanonicalJson,
    'writeCompatibilityText': writeCompatibilityText,
    'createZip': createZip,
    'requireZipPassword': requireZipPassword,
    'includeMetadataReport': includeMetadataReport,
  };

  factory OutputConfig.fromJson(Map<String, Object?> json) => OutputConfig(
    directory: json['directory']! as String,
    writeCanonicalJson: json['writeCanonicalJson'] as bool? ?? false,
    writeCompatibilityText: json['writeCompatibilityText'] as bool? ?? false,
    createZip: json['createZip'] as bool? ?? false,
    requireZipPassword: json['requireZipPassword'] as bool? ?? false,
    includeMetadataReport: json['includeMetadataReport'] as bool? ?? false,
  );
}

class CentraProfile {
  const CentraProfile({
    required this.id,
    required this.name,
    required this.locale,
    required this.source,
    required this.algorithmIds,
    required this.includePatterns,
    required this.excludePatterns,
    required this.customAlgorithms,
    required this.symlinkPolicy,
    required this.includeHiddenFiles,
    required this.capturePermissions,
    required this.captureModificationTimes,
    required this.workerCount,
    required this.failOnReadError,
    required this.output,
    required this.projectKind,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String locale;
  final SourceConfig source;
  final List<String> algorithmIds;
  final List<String> includePatterns;
  final List<String> excludePatterns;
  final List<CustomHashAlgorithm> customAlgorithms;
  final SymlinkPolicy symlinkPolicy;
  final bool includeHiddenFiles;
  final bool capturePermissions;
  final bool captureModificationTimes;
  final int workerCount;
  final bool failOnReadError;
  final OutputConfig output;
  final String projectKind;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<String> validate() {
    final errors = <String>[];
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{1,63}$').hasMatch(id)) {
      errors.add(
        'Profile ID must be 2-64 lowercase letters, numbers, dots, dashes, or underscores.',
      );
    }
    if (name.trim().isEmpty) errors.add('Profile name is required.');
    if (algorithmIds.isEmpty)
      errors.add('Select at least one hash or checksum algorithm.');
    if (algorithmIds.toSet().length != algorithmIds.length)
      errors.add('Algorithm IDs must be unique.');
    if (workerCount < 1 || workerCount > 64)
      errors.add('Worker count must be between 1 and 64.');
    errors
      ..addAll(source.validate())
      ..addAll(output.validate());
    final registry = AlgorithmRegistry(customAlgorithms: customAlgorithms);
    for (final id in algorithmIds) {
      try {
        registry.descriptor(id);
      } on ArgumentError {
        errors.add('Unknown algorithm: $id');
      }
    }
    for (final algorithm in customAlgorithms) {
      if (!RegExp(r'^[a-z0-9][a-z0-9._-]{1,63}$').hasMatch(algorithm.id)) {
        errors.add('Invalid custom algorithm ID: ${algorithm.id}');
      }
      if (!algorithm.arguments.any((argument) => argument.contains('{file}'))) {
        errors.add(
          'Custom algorithm ${algorithm.id} must include {file} in its arguments.',
        );
      }
      try {
        RegExp(algorithm.outputPattern);
      } on FormatException {
        errors.add(
          'Custom algorithm ${algorithm.id} has an invalid output pattern.',
        );
      }
    }
    return errors;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 'centra.profile.v1',
    'id': id,
    'name': name,
    'locale': locale,
    'source': source.toJson(),
    'algorithmIds': algorithmIds,
    'includePatterns': includePatterns,
    'excludePatterns': excludePatterns,
    'customAlgorithms': customAlgorithms
        .map((algorithm) => algorithm.toJson())
        .toList(),
    'symlinkPolicy': symlinkPolicy.wireName,
    'includeHiddenFiles': includeHiddenFiles,
    'capturePermissions': capturePermissions,
    'captureModificationTimes': captureModificationTimes,
    'workerCount': workerCount,
    'failOnReadError': failOnReadError,
    'output': output.toJson(),
    'projectKind': projectKind,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory CentraProfile.fromJson(Map<String, Object?> json) {
    if (json['schema'] != 'centra.profile.v1') {
      throw FormatException('Unsupported profile schema: ${json['schema']}');
    }
    return CentraProfile(
      id: json['id']! as String,
      name: json['name']! as String,
      locale: json['locale'] as String? ?? 'en',
      source: SourceConfig.fromJson(
        (json['source']! as Map).cast<String, Object?>(),
      ),
      algorithmIds: (json['algorithmIds']! as List<Object?>).cast<String>(),
      includePatterns:
          (json['includePatterns'] as List<Object?>? ?? const <Object?>['**'])
              .cast<String>(),
      excludePatterns:
          (json['excludePatterns'] as List<Object?>? ?? const <Object?>[])
              .cast<String>(),
      customAlgorithms:
          (json['customAlgorithms'] as List<Object?>? ?? const <Object?>[])
              .map(
                (value) => CustomHashAlgorithm.fromJson(
                  (value! as Map).cast<String, Object?>(),
                ),
              )
              .toList(growable: false),
      symlinkPolicy: SymlinkPolicyName.parse(
        json['symlinkPolicy'] as String? ?? 'skip',
      ),
      includeHiddenFiles: json['includeHiddenFiles'] as bool? ?? true,
      capturePermissions: json['capturePermissions'] as bool? ?? true,
      captureModificationTimes:
          json['captureModificationTimes'] as bool? ?? true,
      workerCount: json['workerCount'] as int? ?? 4,
      failOnReadError: json['failOnReadError'] as bool? ?? true,
      output: OutputConfig.fromJson(
        (json['output']! as Map).cast<String, Object?>(),
      ),
      projectKind: json['projectKind'] as String? ?? 'generic',
      createdAt: DateTime.parse(json['createdAt']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
    );
  }
}
