import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:centra/src/core/docker_browser.dart';
import 'package:centra/src/core/profile.dart';
import 'package:centra/src/core/source.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('Docker resource and filesystem navigation', () {
    test('lists running containers without invoking a shell', () async {
      final runner = FakeCommandRunner(
        defaultResult: textResult(
          'abc123\tapi-1\texample/api:1\tUp 2 hours\n'
          'def456\tworker-1\texample/worker:1\tUp 1 hour\n',
        ),
      );
      final service = DockerBrowserService(runner: runner);

      final resources = await service.listResources(
        SourceType.dockerContainer,
        dockerContext: 'production',
      );

      expect(resources.map((resource) => resource.title), <String>[
        'api-1',
        'worker-1',
      ]);
      expect(resources.first.reference, 'abc123');
      expect(
        runner.commands.single.arguments,
        <String>[
          '--context',
          'production',
          'ps',
          '--format',
          '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}',
        ],
      );
    });

    test('lists tagged images and keeps untagged images addressable', () async {
      final runner = FakeCommandRunner(
        defaultResult: textResult(
          'example/api\t1.2.0\tsha256:aaa\t120MB\n'
          '<none>\t<none>\tsha256:bbb\t80MB\n',
        ),
      );
      final service = DockerBrowserService(runner: runner);

      final resources = await service.listResources(SourceType.dockerImage);

      expect(resources[0].reference, 'example/api:1.2.0');
      expect(resources[1].reference, 'sha256:bbb');
    });

    test('browses container directories from docker cp tar output', () async {
      final rootArchive = Archive()
        ..add(ArchiveFile.string('app/lib/main.dart', 'void main() {}'))
        ..add(ArchiveFile.string('usr/bin/tool', 'binary'))
        ..add(ArchiveFile.string('root.txt', 'file'));
      final appArchive = Archive()
        ..add(ArchiveFile.string('lib/main.dart', 'void main() {}'))
        ..add(ArchiveFile.string('pubspec.yaml', 'name: app'));
      final runner = FakeCommandRunner(handler: (executable, arguments) async {
        final source = arguments[arguments.indexOf('cp') + 1];
        final archive = source.contains(':/app/.') ? appArchive : rootArchive;
        return ProcessResultData(
          exitCode: 0,
          stdoutBytes: Uint8List.fromList(TarEncoder().encodeBytes(archive)),
          stderrBytes: Uint8List(0),
        );
      });
      final service = DockerBrowserService(runner: runner);
      const resource = DockerResource(
        reference: 'abc123',
        title: 'api-1',
        subtitle: 'example/api:1',
      );
      final session = await service.open(
        SourceType.dockerContainer,
        resource,
      );

      final root = await session.listDirectories('/');
      final app = await session.listDirectories('/app');

      expect(
        root.entries.map((entry) => entry.name),
        <String>['app', 'usr'],
      );
      expect(
        app.entries.map((entry) => entry.name),
        <String>['..', 'lib'],
      );
      expect(app.parentPath, '/');
      expect(
        runner.commands.every((command) => !command.arguments.contains('sh')),
        isTrue,
      );
    });

    test('temporary image container is removed when browsing closes', () async {
      final archive = Archive()..add(ArchiveFile.string('app/main', 'binary'));
      final runner = FakeCommandRunner(handler: (executable, arguments) async {
        if (arguments.contains('create')) return textResult('temporary-123\n');
        if (arguments.contains('cp')) {
          return ProcessResultData(
            exitCode: 0,
            stdoutBytes: Uint8List.fromList(TarEncoder().encodeBytes(archive)),
            stderrBytes: Uint8List(0),
          );
        }
        return textResult('');
      });
      final service = DockerBrowserService(runner: runner);
      const resource = DockerResource(
        reference: 'example/api:1',
        title: 'example/api:1',
        subtitle: 'sha256:abc',
      );

      final session = await service.open(SourceType.dockerImage, resource);
      await session.listDirectories('/');
      await session.dispose();

      expect(
        runner.commands.any(
          (command) =>
              command.arguments.length >= 3 &&
              command.arguments[0] == 'rm' &&
              command.arguments[1] == '-f' &&
              command.arguments[2] == 'temporary-123',
        ),
        isTrue,
      );
    });

    test('compose service is created only when no container exists', () async {
      var psCalls = 0;
      final runner = FakeCommandRunner(handler: (executable, arguments) async {
        if (arguments.contains('ps')) {
          psCalls++;
          return textResult(psCalls == 1 ? '' : 'compose-container\n');
        }
        return textResult('');
      });
      final service = DockerBrowserService(runner: runner);
      const resource = DockerResource(
        reference: 'api',
        title: 'api',
        subtitle: 'Docker Compose service',
      );

      final session = await service.open(
        SourceType.dockerCompose,
        resource,
        composeFile: 'compose.yml',
      );
      await session.dispose();

      expect(
        runner.commands.any(
          (command) => command.arguments.containsAll(<String>[
            'compose',
            '-f',
            'compose.yml',
            'create',
            'api',
          ]),
        ),
        isTrue,
      );
      expect(
        runner.commands.any(
          (command) => command.arguments.containsAll(<String>[
            'rm',
            '-f',
            'compose-container',
          ]),
        ),
        isTrue,
      );
    });
  });

  group('Docker paths', () {
    test('normalizes paths as absolute POSIX container paths', () {
      expect(normalizeDockerPath('app\\data'), '/app/data');
      expect(normalizeDockerPath('/app/../srv'), '/srv');
      expect(normalizeDockerPath(''), '/');
      expect(dockerParentPath('/srv/app'), '/srv');
      expect(dockerParentPath('/'), isNull);
    });
  });
}
