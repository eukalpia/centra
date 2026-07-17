import 'dart:io';
import 'dart:math';

import 'package:centra/centra.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('IntegrityScanner', () {
    late Directory project;

    tearDown(() async {
      if (await project.exists()) await project.delete(recursive: true);
    });

    test('hashes multiple algorithms while applying exclusions', () async {
      project = await createProject(<String, String>{
        'lib/main.dart': 'void main() {}',
        'README.md': 'hello',
        '.env': 'SECRET=1',
        'node_modules/pkg/index.js': 'generated',
      });
      final profile = testProfile(
        root: project.path,
        algorithmIds: const <String>['sha256', 'md5', 'crc32'],
        excludes: const <String>['**/.env', 'node_modules/**'],
        workerCount: 3,
      );
      final progress = <ScanProgress>[];
      final result = await IntegrityScanner(
        clock: () => DateTime.utc(2026, 7, 17, 10),
        random: Random(1),
      ).scan(profile, onProgress: progress.add);

      expect(result.manifest.files.map((file) => file.path),
          <String>['README.md', 'lib/main.dart']);
      for (final file in result.manifest.files) {
        expect(file.digests.keys,
            containsAllInOrder(<String>['sha256', 'md5', 'crc32']));
        expect(file.digests['sha256'], hasLength(64));
        expect(file.digests['md5'], hasLength(32));
        expect(file.digests['crc32'], hasLength(8));
      }
      expect(
          result.manifest.algorithms
              .lastWhere((algorithm) => algorithm.id == 'md5')
              .status,
          AlgorithmStatus.obsolete);
      expect(progress.last.phase, 'complete');
      expect(result.manifest.errors, isEmpty);
    });

    test('produces the same content records regardless of worker count',
        () async {
      project = await createProject(<String, String>{
        for (var index = 0; index < 25; index++)
          'files/$index.txt': 'value-$index',
      });
      final oneWorker = await IntegrityScanner(random: Random(2)).scan(
        testProfile(root: project.path, workerCount: 1),
      );
      final eightWorkers = await IntegrityScanner(random: Random(3)).scan(
        testProfile(root: project.path, workerCount: 8),
      );
      expect(
        eightWorkers.manifest.files.map((file) => file.toJson()).toList(),
        oneWorker.manifest.files.map((file) => file.toJson()).toList(),
      );
    });

    test('runs an external custom hash command without a shell', () async {
      project = await createProject(<String, String>{'file.txt': 'content'});
      final runner = FakeCommandRunner(
          defaultResult: textResult('HASH=0123456789abcdef\n'));
      const custom = CustomHashAlgorithm(
        id: 'external-test',
        displayName: 'External test',
        executable: 'hash-tool',
        arguments: <String>['--file', '{file}'],
        outputPattern: r'HASH=([0-9a-f]+)',
        outputGroup: 1,
        outputBits: 64,
      );
      final result = await IntegrityScanner(commandRunner: runner).scan(
        testProfile(
          root: project.path,
          algorithmIds: const <String>['external-test'],
          customAlgorithms: const <CustomHashAlgorithm>[custom],
        ),
      );
      expect(result.manifest.files.single.digests['external-test'],
          '0123456789abcdef');
      expect(runner.commands, hasLength(1));
      expect(runner.commands.single.executable, 'hash-tool');
      expect(runner.commands.single.arguments.first, '--file');
      expect(runner.commands.single.arguments.last, endsWith('file.txt'));
    });

    test('records symlink targets instead of following them when requested',
        () async {
      project = await createProject(<String, String>{'target.txt': 'target'});
      final link = Link('${project.path}/link.txt');
      try {
        await link.create('target.txt');
      } on FileSystemException {
        return;
      }
      final result = await IntegrityScanner().scan(
        testProfile(root: project.path, symlinkPolicy: SymlinkPolicy.record),
      );
      final linkRecord =
          result.manifest.files.singleWhere((file) => file.path == 'link.txt');
      expect(linkRecord.symlinkTarget, 'target.txt');
      expect(linkRecord.digests['sha256'], hasLength(64));
    });
  });
}
