import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'profile.dart';
import 'source.dart';

class DockerResource {
  const DockerResource({
    required this.reference,
    required this.title,
    required this.subtitle,
  });

  final String reference;
  final String title;
  final String subtitle;
}

class DockerDirectoryEntry {
  const DockerDirectoryEntry({
    required this.name,
    required this.path,
    required this.isParent,
  });

  final String name;
  final String path;
  final bool isParent;
}

class DockerDirectoryListing {
  const DockerDirectoryListing({
    required this.path,
    required this.entries,
    required this.parentPath,
  });

  final String path;
  final List<DockerDirectoryEntry> entries;
  final String? parentPath;
}

class DockerSourceSelection {
  const DockerSourceSelection({
    required this.sourceType,
    required this.resource,
    required this.path,
  });

  final SourceType sourceType;
  final DockerResource resource;
  final String path;
}

class DockerBrowseSession {
  DockerBrowseSession({
    required CommandRunner runner,
    required this.sourceType,
    required this.resource,
    required this.containerId,
    required List<String> contextArguments,
    Future<void> Function()? dispose,
  })  : _runner = runner,
        _contextArguments = List<String>.unmodifiable(contextArguments),
        _dispose = dispose;

  final CommandRunner _runner;
  final List<String> _contextArguments;
  final Future<void> Function()? _dispose;

  final SourceType sourceType;
  final DockerResource resource;
  final String containerId;

  var _disposed = false;

  Future<DockerDirectoryListing> listDirectories(String path) async {
    if (_disposed) {
      throw StateError('Docker browsing session is already closed.');
    }

    final normalizedPath = normalizeDockerPath(path);
    final arguments = <String>[
      ..._contextArguments,
      'cp',
      '$containerId:$normalizedPath/.',
      '-',
    ];
    final result = await _runner.run(
      'docker',
      arguments,
      timeout: const Duration(minutes: 5),
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'docker',
        arguments,
        result.stderrText,
        result.exitCode,
      );
    }

    final archive = TarDecoder().decodeBytes(result.stdoutBytes);
    final directoryNames = <String>{};
    final archiveNames = <String>[];
    for (final entry in archive) {
      final name = _normalizeArchiveName(entry.name);
      if (name.isNotEmpty) archiveNames.add(name);
    }

    final selectedBaseName = p.posix.basename(normalizedPath);
    final stripSelectedPrefix = selectedBaseName.isNotEmpty &&
        selectedBaseName != '/' &&
        archiveNames.isNotEmpty &&
        archiveNames.every(
          (name) => name == selectedBaseName || name.startsWith('$selectedBaseName/'),
        );

    for (final entry in archive) {
      var name = _normalizeArchiveName(entry.name);
      if (name.isEmpty) continue;
      var segments = p.posix
          .split(name)
          .where((segment) => segment.isNotEmpty && segment != '.')
          .toList(growable: true);
      if (stripSelectedPrefix &&
          segments.isNotEmpty &&
          segments.first == selectedBaseName) {
        segments = segments.sublist(1);
      }
      if (segments.isEmpty) continue;
      if (segments.length > 1 || entry.isDirectory) {
        directoryNames.add(segments.first);
      }
    }

    final sorted = directoryNames.toList(growable: false)
      ..sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
    final parentPath = dockerParentPath(normalizedPath);
    final entries = <DockerDirectoryEntry>[
      if (parentPath != null)
        DockerDirectoryEntry(name: '..', path: parentPath, isParent: true),
      ...sorted.map(
        (name) => DockerDirectoryEntry(
          name: name,
          path: normalizeDockerPath(p.posix.join(normalizedPath, name)),
          isParent: false,
        ),
      ),
    ];

    return DockerDirectoryListing(
      path: normalizedPath,
      entries: List<DockerDirectoryEntry>.unmodifiable(entries),
      parentPath: parentPath,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _dispose?.call();
  }
}

class DockerBrowserService {
  DockerBrowserService({CommandRunner runner = const SystemCommandRunner()})
      : _runner = runner;

  final CommandRunner _runner;

  Future<List<DockerResource>> listResources(
    SourceType sourceType, {
    String? dockerContext,
    String? composeFile,
  }) async {
    switch (sourceType) {
      case SourceType.dockerContainer:
        return _listContainers(dockerContext);
      case SourceType.dockerImage:
        return _listImages(dockerContext);
      case SourceType.dockerCompose:
        return _listComposeServices(
          dockerContext: dockerContext,
          composeFile: composeFile,
        );
      case SourceType.local:
      case SourceType.ssh:
        throw ArgumentError.value(
          sourceType,
          'sourceType',
          'Docker browser supports only Docker sources.',
        );
    }
  }

  Future<DockerBrowseSession> open(
    SourceType sourceType,
    DockerResource resource, {
    String? dockerContext,
    String? composeFile,
  }) async {
    final contextArguments = _dockerContextArguments(dockerContext);
    switch (sourceType) {
      case SourceType.dockerContainer:
        return DockerBrowseSession(
          runner: _runner,
          sourceType: sourceType,
          resource: resource,
          containerId: resource.reference,
          contextArguments: contextArguments,
        );
      case SourceType.dockerImage:
        final createArguments = <String>[
          ...contextArguments,
          'create',
          resource.reference,
        ];
        final result = await _run('docker', createArguments);
        final containerId = result.stdoutText.trim();
        if (containerId.isEmpty) {
          throw StateError('Docker create returned an empty container ID.');
        }
        return DockerBrowseSession(
          runner: _runner,
          sourceType: sourceType,
          resource: resource,
          containerId: containerId,
          contextArguments: contextArguments,
          dispose: () => _removeContainer(containerId, contextArguments),
        );
      case SourceType.dockerCompose:
        final composeArguments = _composeArguments(
          dockerContext: dockerContext,
          composeFile: composeFile,
        );
        var createdForBrowsing = false;
        var containerId = await _composeContainerId(
          composeArguments,
          resource.reference,
        );
        if (containerId.isEmpty) {
          await _run(
            'docker',
            <String>[...composeArguments, 'create', resource.reference],
          );
          createdForBrowsing = true;
          containerId = await _composeContainerId(
            composeArguments,
            resource.reference,
          );
        }
        if (containerId.isEmpty) {
          throw StateError(
            'Docker Compose did not return a container for ${resource.reference}.',
          );
        }
        return DockerBrowseSession(
          runner: _runner,
          sourceType: sourceType,
          resource: resource,
          containerId: containerId,
          contextArguments: contextArguments,
          dispose: createdForBrowsing
              ? () => _removeContainer(containerId, contextArguments)
              : null,
        );
      case SourceType.local:
      case SourceType.ssh:
        throw ArgumentError.value(
          sourceType,
          'sourceType',
          'Docker browser supports only Docker sources.',
        );
    }
  }

  Future<List<DockerResource>> _listContainers(String? dockerContext) async {
    final result = await _run(
      'docker',
      <String>[
        ..._dockerContextArguments(dockerContext),
        'ps',
        '--format',
        '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}',
      ],
    );
    final resources = <DockerResource>[];
    for (final line in const LineSplitter().convert(result.stdoutText)) {
      final fields = line.split('\t');
      if (fields.isEmpty || fields.first.trim().isEmpty) continue;
      final id = fields[0].trim();
      final name = fields.length > 1 ? fields[1].trim() : id;
      final image = fields.length > 2 ? fields[2].trim() : '';
      final status = fields.length > 3 ? fields[3].trim() : '';
      resources.add(
        DockerResource(
          reference: id,
          title: name.isEmpty ? id : name,
          subtitle: <String>[image, status]
              .where((value) => value.isNotEmpty)
              .join(' · '),
        ),
      );
    }
    return List<DockerResource>.unmodifiable(resources);
  }

  Future<List<DockerResource>> _listImages(String? dockerContext) async {
    final result = await _run(
      'docker',
      <String>[
        ..._dockerContextArguments(dockerContext),
        'image',
        'ls',
        '--format',
        '{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}',
      ],
    );
    final resources = <DockerResource>[];
    final seen = <String>{};
    for (final line in const LineSplitter().convert(result.stdoutText)) {
      final fields = line.split('\t');
      if (fields.length < 3) continue;
      final repository = fields[0].trim();
      final tag = fields[1].trim();
      final id = fields[2].trim();
      final size = fields.length > 3 ? fields[3].trim() : '';
      if (id.isEmpty) continue;
      final hasNamedReference = repository.isNotEmpty &&
          repository != '<none>' &&
          tag.isNotEmpty &&
          tag != '<none>';
      final reference = hasNamedReference ? '$repository:$tag' : id;
      if (!seen.add('$reference\u0000$id')) continue;
      resources.add(
        DockerResource(
          reference: reference,
          title: reference,
          subtitle: <String>[id, size]
              .where((value) => value.isNotEmpty)
              .join(' · '),
        ),
      );
    }
    return List<DockerResource>.unmodifiable(resources);
  }

  Future<List<DockerResource>> _listComposeServices({
    String? dockerContext,
    String? composeFile,
  }) async {
    final result = await _run(
      'docker',
      <String>[
        ..._composeArguments(
          dockerContext: dockerContext,
          composeFile: composeFile,
        ),
        'config',
        '--services',
      ],
    );
    final services = const LineSplitter()
        .convert(result.stdoutText)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return List<DockerResource>.unmodifiable(
      services.map(
        (service) => DockerResource(
          reference: service,
          title: service,
          subtitle: 'Docker Compose service',
        ),
      ),
    );
  }

  Future<String> _composeContainerId(
    List<String> composeArguments,
    String service,
  ) async {
    final result = await _run(
      'docker',
      <String>[...composeArguments, 'ps', '-a', '-q', service],
    );
    return const LineSplitter()
        .convert(result.stdoutText)
        .map((value) => value.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  }

  Future<void> _removeContainer(
    String containerId,
    List<String> contextArguments,
  ) async {
    await _runner.run(
      'docker',
      <String>[...contextArguments, 'rm', '-f', containerId],
      timeout: const Duration(minutes: 2),
    );
  }

  Future<ProcessResultData> _run(
    String executable,
    List<String> arguments,
  ) async {
    final result = await _runner.run(
      executable,
      arguments,
      timeout: const Duration(minutes: 10),
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        result.stderrText,
        result.exitCode,
      );
    }
    return result;
  }
}

String normalizeDockerPath(String path) {
  var value = path.trim().replaceAll('\\', '/');
  if (value.isEmpty) return '/';
  if (!value.startsWith('/')) value = '/$value';
  value = p.posix.normalize(value);
  return value == '.' ? '/' : value;
}

String? dockerParentPath(String path) {
  final normalized = normalizeDockerPath(path);
  if (normalized == '/') return null;
  final parent = p.posix.dirname(normalized);
  return parent == '.' || parent.isEmpty ? '/' : normalizeDockerPath(parent);
}

String _normalizeArchiveName(String name) {
  var value = name.replaceAll('\\', '/');
  while (value.startsWith('./')) {
    value = value.substring(2);
  }
  value = p.posix.normalize(value);
  return value == '.' || value == '/' ? '' : value.replaceFirst(RegExp(r'^/+'), '');
}

List<String> _dockerContextArguments(String? dockerContext) {
  final value = dockerContext?.trim() ?? '';
  return value.isEmpty ? const <String>[] : <String>['--context', value];
}

List<String> _composeArguments({
  String? dockerContext,
  String? composeFile,
}) {
  final file = composeFile?.trim() ?? '';
  return <String>[
    ..._dockerContextArguments(dockerContext),
    'compose',
    if (file.isNotEmpty) ...<String>['-f', file],
  ];
}
