import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:centra/centra.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('source adapters', () {
    test('Docker container adapter includes the selected context', () async {
      final archive = Archive()..add(ArchiveFile.string('app.txt', 'ok'));
      final runner = FakeCommandRunner(
        defaultResult: ProcessResultData(
          exitCode: 0,
          stdoutBytes: Uint8List.fromList(TarEncoder().encodeBytes(archive)),
          stderrBytes: Uint8List(0),
        ),
      );
      final provider = ArchiveSourceProvider(
        type: SourceType.dockerContainer,
        runner: runner,
      );
      final prepared = await provider.prepare(
        const SourceConfig(
          type: SourceType.dockerContainer,
          root: '/app',
          container: 'api-1',
          dockerContext: 'production',
        ),
      );
      try {
        expect(
          runner.commands.single.arguments,
          containsAllInOrder(<String>[
            '--context',
            'production',
            'exec',
            'api-1',
            'tar',
            '-C',
            '/app',
            '-cf',
            '-',
            '.',
          ]),
        );
      } finally {
        await prepared.dispose();
      }
    });

    test('safe tar extraction rejects parent traversal', () async {
      final directory =
          await Directory.systemTemp.createTemp('centra-tar-test-');
      final archive = Archive()
        ..add(ArchiveFile.string('../escape.txt', 'bad'));
      try {
        expect(
          () => extractTarSafely(TarEncoder().encodeBytes(archive), directory),
          throwsA(isA<FormatException>()),
        );
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('Docker image provider removes its temporary container on failure',
        () async {
      final runner = FakeCommandRunner(handler: (executable, arguments) async {
        if (arguments.contains('create')) return textResult('container-123\n');
        if (arguments.contains('cp')) {
          return textResult('', stderr: 'copy failed', exitCode: 1);
        }
        return textResult('');
      });
      final provider = DockerImageSourceProvider(runner);
      await expectLater(
        provider.prepare(
          const SourceConfig(
            type: SourceType.dockerImage,
            root: '/app',
            image: 'example/app:1',
          ),
        ),
        throwsA(isA<ProcessException>()),
      );
      expect(
        runner.commands.any(
          (command) =>
              command.arguments.length >= 3 &&
              command.arguments[0] == 'rm' &&
              command.arguments[1] == '-f' &&
              command.arguments[2] == 'container-123',
        ),
        isTrue,
      );
    });
  });
}
