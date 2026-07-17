import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:centra/centra.dart';

CentraProfile testProfile({
  required String root,
  String id = 'test-profile',
  List<String> algorithmIds = const <String>['sha256'],
  List<String> excludes = const <String>[],
  List<CustomHashAlgorithm> customAlgorithms = const <CustomHashAlgorithm>[],
  OutputConfig? output,
  SourceConfig? source,
  SymlinkPolicy symlinkPolicy = SymlinkPolicy.skip,
  bool includeHiddenFiles = true,
  bool capturePermissions = false,
  bool captureModificationTimes = false,
  bool failOnReadError = true,
  int workerCount = 2,
}) {
  final now = DateTime.utc(2026, 7, 17, 10);
  return CentraProfile(
    id: id,
    name: 'Test profile',
    locale: 'en',
    source: source ?? SourceConfig(type: SourceType.local, root: root),
    algorithmIds: algorithmIds,
    includePatterns: const <String>['**'],
    excludePatterns: excludes,
    customAlgorithms: customAlgorithms,
    symlinkPolicy: symlinkPolicy,
    includeHiddenFiles: includeHiddenFiles,
    capturePermissions: capturePermissions,
    captureModificationTimes: captureModificationTimes,
    workerCount: workerCount,
    failOnReadError: failOnReadError,
    output: output ?? OutputConfig(
      directory: '$root/output',
      writeCanonicalJson: true,
      writeCompatibilityText: false,
      createZip: false,
      requireZipPassword: false,
      includeMetadataReport: false,
    ),
    projectKind: 'generic',
    createdAt: now,
    updatedAt: now,
  );
}

CentraManifest testManifest({
  String id = 'manifest-1',
  List<ManifestFileRecord>? files,
  List<HashAlgorithmDescriptor>? algorithms,
  DateTime? generatedAt,
}) {
  final records = files ?? <ManifestFileRecord>[
    const ManifestFileRecord(
      path: 'lib/main.dart',
      size: 3,
      digests: <String, String>{'sha256': 'abc123'},
    ),
  ];
  return CentraManifest(
    id: id,
    generatedAt: generatedAt ?? DateTime.utc(2026, 7, 17, 10),
    toolVersion: '0.1.0',
    profileId: 'test-profile',
    profileName: 'Test profile',
    projectKind: 'dart',
    source: const <String, Object?>{'type': 'local', 'root': '/tmp/project'},
    algorithms: algorithms ?? <HashAlgorithmDescriptor>[AlgorithmRegistry().descriptor('sha256')],
    includePatterns: const <String>['**'],
    excludePatterns: const <String>['.git/**'],
    files: records,
    errors: const <ManifestReadError>[],
    totalBytes: records.fold<int>(0, (sum, file) => sum + file.size),
  );
}

class RecordedCommand {
  const RecordedCommand({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
    required this.timeout,
  });

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String>? environment;
  final Duration? timeout;
}

class FakeCommandRunner implements CommandRunner {
  FakeCommandRunner({
    this.handler,
    ProcessResultData? defaultResult,
  }) : defaultResult = defaultResult ?? ProcessResultData(
          exitCode: 0,
          stdoutBytes: Uint8List(0),
          stderrBytes: Uint8List(0),
        );

  final Future<ProcessResultData> Function(String executable, List<String> arguments)? handler;
  final ProcessResultData defaultResult;
  final List<RecordedCommand> commands = <RecordedCommand>[];

  @override
  Future<ProcessResultData> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    commands.add(RecordedCommand(
      executable: executable,
      arguments: List<String>.unmodifiable(arguments),
      workingDirectory: workingDirectory,
      environment: environment == null ? null : Map<String, String>.unmodifiable(environment),
      timeout: timeout,
    ));
    return handler?.call(executable, arguments) ?? defaultResult;
  }
}

ProcessResultData textResult(String stdout, {String stderr = '', int exitCode = 0}) => ProcessResultData(
      exitCode: exitCode,
      stdoutBytes: Uint8List.fromList(utf8.encode(stdout)),
      stderrBytes: Uint8List.fromList(utf8.encode(stderr)),
    );

Future<Directory> createProject(Map<String, String> files) async {
  final directory = await Directory.systemTemp.createTemp('centra-test-project-');
  for (final entry in files.entries) {
    final file = File('${directory.path}/${entry.key}');
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value, flush: true);
  }
  return directory;
}
