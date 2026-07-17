import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'path_policy.dart';
import 'profile.dart';
import 'ssh_connection.dart';

class ProcessResultData {
  const ProcessResultData({
    required this.exitCode,
    required this.stdoutBytes,
    required this.stderrBytes,
  });

  final int exitCode;
  final Uint8List stdoutBytes;
  final Uint8List stderrBytes;

  String get stdoutText => utf8.decode(stdoutBytes, allowMalformed: true);
  String get stderrText => utf8.decode(stderrBytes, allowMalformed: true);
}

abstract interface class CommandRunner {
  Future<ProcessResultData> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  });
}

class SystemCommandRunner implements CommandRunner {
  const SystemCommandRunner();

  @override
  Future<ProcessResultData> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    final future = Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: false,
      stdoutEncoding: null,
      stderrEncoding: null,
    );
    final result =
        timeout == null ? await future : await future.timeout(timeout);
    return ProcessResultData(
      exitCode: result.exitCode,
      stdoutBytes:
          Uint8List.fromList((result.stdout as List<int>?) ?? const <int>[]),
      stderrBytes:
          Uint8List.fromList((result.stderr as List<int>?) ?? const <int>[]),
    );
  }
}

class PreparedSource {
  PreparedSource({
    required this.directory,
    required this.metadata,
    Future<void> Function()? dispose,
  }) : _dispose = dispose;

  final Directory directory;
  final Map<String, Object?> metadata;
  final Future<void> Function()? _dispose;
  var _disposed = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _dispose?.call();
  }
}

abstract interface class SourceProvider {
  SourceType get type;

  Future<PreparedSource> prepare(
    SourceConfig config, {
    SshConnectionSecrets? sshSecrets,
  });
}

class LocalSourceProvider implements SourceProvider {
  const LocalSourceProvider();

  @override
  SourceType get type => SourceType.local;

  @override
  Future<PreparedSource> prepare(
    SourceConfig config, {
    SshConnectionSecrets? sshSecrets,
  }) async {
    final directory = Directory(config.root).absolute;
    if (!await directory.exists()) {
      throw FileSystemException(
          'Local source directory does not exist.', directory.path);
    }
    return PreparedSource(
      directory: directory,
      metadata: <String, Object?>{
        'type': type.wireName,
        'root': directory.path,
      },
    );
  }
}

class SshSourceProvider implements SourceProvider {
  const SshSourceProvider({
    this.service = const SshConnectionService(),
  });

  final SshConnectionService service;

  @override
  SourceType get type => SourceType.ssh;

  @override
  Future<PreparedSource> prepare(
    SourceConfig config, {
    SshConnectionSecrets? sshSecrets,
  }) async {
    final connection = await service.connect(
      config,
      secrets: sshSecrets ?? const SshConnectionSecrets(),
    );
    try {
      final snapshot = await connection.downloadSnapshot(config.root);
      return PreparedSource(
        directory: snapshot.directory,
        metadata: <String, Object?>{
          'type': type.wireName,
          'root': config.root,
          'host': config.host,
          'user': config.user,
          'port': config.port,
          'authMethod': config.sshAuthMethod.wireName,
          'hostKeyType': connection.hostKeyType,
          'hostKeyFingerprint': connection.hostKeyFingerprint,
          'serverVersion': connection.serverVersion,
          'snapshotFiles': snapshot.files,
          'snapshotDirectories': snapshot.directories,
          'snapshotSymlinks': snapshot.symlinks,
        },
        dispose: () async {
          await connection.close();
          if (await snapshot.directory.exists()) {
            await snapshot.directory.delete(recursive: true);
          }
        },
      );
    } catch (_) {
      await connection.close();
      rethrow;
    }
  }
}

class ArchiveSourceProvider implements SourceProvider {
  ArchiveSourceProvider({
    required this.type,
    required this.runner,
  });

  @override
  final SourceType type;
  final CommandRunner runner;

  @override
  Future<PreparedSource> prepare(
    SourceConfig config, {
    SshConnectionSecrets? sshSecrets,
  }) async {
    final temp = await Directory.systemTemp.createTemp('centra-source-');
    try {
      final command = _command(config);
      final result = await runner.run(
        command.$1,
        command.$2,
        timeout: const Duration(minutes: 30),
      );
      if (result.exitCode != 0) {
        throw ProcessException(
            command.$1, command.$2, result.stderrText, result.exitCode);
      }
      final snapshot = Directory(p.join(temp.path, 'snapshot'));
      await snapshot.create(recursive: true);
      await extractTarSafely(result.stdoutBytes, snapshot);
      return PreparedSource(
        directory: snapshot,
        metadata: _metadata(config),
        dispose: () => temp.delete(recursive: true),
      );
    } catch (_) {
      if (await temp.exists()) await temp.delete(recursive: true);
      rethrow;
    }
  }

  (String, List<String>) _command(SourceConfig config) {
    switch (type) {
      case SourceType.ssh:
        throw UnsupportedError('SSH snapshots use SshSourceProvider.');
      case SourceType.dockerContainer:
        return (
          'docker',
          <String>[
            ...dockerContextArguments(config),
            'exec',
            config.container!,
            'tar',
            '-C',
            config.root,
            '-cf',
            '-',
            '.',
          ],
        );
      case SourceType.dockerCompose:
        return (
          'docker',
          <String>[
            ...dockerContextArguments(config),
            'compose',
            if ((config.composeFile ?? '').isNotEmpty) ...<String>[
              '-f',
              config.composeFile!
            ],
            'exec',
            '-T',
            config.service!,
            'tar',
            '-C',
            config.root,
            '-cf',
            '-',
            '.',
          ],
        );
      case SourceType.dockerImage:
        throw UnsupportedError(
            'Docker image snapshots are prepared by DockerImageSourceProvider.');
      case SourceType.local:
        throw UnsupportedError(
            'Local sources do not use ArchiveSourceProvider.');
    }
  }

  Map<String, Object?> _metadata(SourceConfig config) => <String, Object?>{
        'type': type.wireName,
        'root': config.root,
        if (config.host != null) 'host': config.host,
        if (config.user != null) 'user': config.user,
        if (type == SourceType.ssh) 'port': config.port,
        if (config.container != null) 'container': config.container,
        if (config.service != null) 'service': config.service,
        if (config.composeFile != null) 'composeFile': config.composeFile,
        if (config.dockerContext != null) 'dockerContext': config.dockerContext,
      };
}

List<String> dockerContextArguments(SourceConfig config) =>
    (config.dockerContext ?? '').isEmpty
        ? const <String>[]
        : <String>['--context', config.dockerContext!];

Future<void> extractTarSafely(List<int> bytes, Directory destination) async {
  final archive = TarDecoder().decodeBytes(bytes);
  final root = destination.absolute.path;
  for (final entry in archive) {
    final normalized = normalizeRelativePath(entry.name);
    if (normalized.isEmpty) continue;
    final outputPath = p.joinAll(<String>[root, ...normalized.split('/')]);
    if (!p.isWithin(root, outputPath)) {
      throw FormatException('Archive entry escapes destination: ${entry.name}');
    }
    if (entry.isDirectory) {
      await Directory(outputPath).create(recursive: true);
    } else if (entry.isFile) {
      final content = entry.readBytes();
      if (content == null) {
        throw FormatException(
            'Archive file has no readable content: ${entry.name}');
      }
      await File(outputPath).parent.create(recursive: true);
      await File(outputPath).writeAsBytes(content, flush: true);
    }
  }
}

class DockerImageSourceProvider implements SourceProvider {
  DockerImageSourceProvider(this.runner);

  final CommandRunner runner;

  @override
  SourceType get type => SourceType.dockerImage;

  @override
  Future<PreparedSource> prepare(
    SourceConfig config, {
    SshConnectionSecrets? sshSecrets,
  }) async {
    final createArguments = <String>[
      ...dockerContextArguments(config),
      'create',
      config.image!,
    ];
    final create = await runner.run('docker', createArguments,
        timeout: const Duration(minutes: 10));
    if (create.exitCode != 0) {
      throw ProcessException(
          'docker', createArguments, create.stderrText, create.exitCode);
    }
    final containerId = create.stdoutText.trim();
    if (containerId.isEmpty) {
      throw StateError('Docker create returned an empty container ID.');
    }
    final temp = await Directory.systemTemp.createTemp('centra-image-');
    Future<void> removeContainer() async {
      await runner.run(
        'docker',
        <String>[...dockerContextArguments(config), 'rm', '-f', containerId],
      );
    }

    try {
      final copyArguments = <String>[
        ...dockerContextArguments(config),
        'cp',
        '$containerId:${config.root}/.',
        temp.path,
      ];
      final copy = await runner.run('docker', copyArguments,
          timeout: const Duration(minutes: 30));
      if (copy.exitCode != 0) {
        throw ProcessException(
            'docker', copyArguments, copy.stderrText, copy.exitCode);
      }
      return PreparedSource(
        directory: temp,
        metadata: <String, Object?>{
          'type': type.wireName,
          'image': config.image,
          'root': config.root,
          if (config.dockerContext != null)
            'dockerContext': config.dockerContext,
        },
        dispose: () async {
          await removeContainer();
          if (await temp.exists()) await temp.delete(recursive: true);
        },
      );
    } catch (_) {
      await removeContainer();
      if (await temp.exists()) await temp.delete(recursive: true);
      rethrow;
    }
  }
}

class SourceRegistry {
  SourceRegistry({CommandRunner runner = const SystemCommandRunner()})
      : _providers = <SourceType, SourceProvider>{
          SourceType.local: const LocalSourceProvider(),
          SourceType.ssh: const SshSourceProvider(),
          SourceType.dockerContainer: ArchiveSourceProvider(
              type: SourceType.dockerContainer, runner: runner),
          SourceType.dockerImage: DockerImageSourceProvider(runner),
          SourceType.dockerCompose: ArchiveSourceProvider(
              type: SourceType.dockerCompose, runner: runner),
        };

  final Map<SourceType, SourceProvider> _providers;

  SourceProvider provider(SourceType type) => _providers[type]!;
}
