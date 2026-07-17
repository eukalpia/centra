import 'dart:convert';
import 'dart:io';

import 'package:centra/centra.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('Centra storage', () {
    late Directory sandbox;
    late CentraPaths paths;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('centra-storage-test-');
      paths = CentraPaths(
        configDirectory: Directory('${sandbox.path}/config'),
        dataDirectory: Directory('${sandbox.path}/data'),
      );
    });

    tearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    test('creates isolated configuration and data directories', () async {
      await paths.ensure();

      expect(await paths.configDirectory.exists(), isTrue);
      expect(await paths.profilesDirectory.exists(), isTrue);
      expect(await paths.dataDirectory.exists(), isTrue);
      expect(await paths.historyDirectory.exists(), isTrue);
    });

    test('settings default and persisted values round-trip', () async {
      final store = SettingsStore(paths);
      expect((await store.load()).toJson(), CentraSettings.defaults.toJson());

      const settings = CentraSettings(
        locale: 'ru',
        theme: 'dark',
        confirmDestructiveActions: false,
      );
      await store.save(settings);

      expect((await store.load()).toJson(), settings.toJson());
      expect(
        await paths.settingsFile.readAsString(),
        contains('centra.settings.v1'),
      );
    });

    test('profile store saves, sorts, loads and deletes profiles', () async {
      final store = ProfileStore(paths);
      final first = testProfile(root: sandbox.path, id: 'zeta-profile');
      final second = CentraProfile.fromJson(<String, Object?>{
        ...testProfile(root: sandbox.path, id: 'alpha-profile').toJson(),
        'name': 'Alpha profile',
      });

      await store.save(first);
      await store.save(second);

      final profiles = await store.list();
      expect(profiles.map((profile) => profile.id), <String>[
        'alpha-profile',
        'zeta-profile',
      ]);
      expect((await store.load('alpha-profile'))?.name, 'Alpha profile');
      expect(await store.delete('alpha-profile'), isTrue);
      expect(await store.delete('alpha-profile'), isFalse);
      expect(await store.load('alpha-profile'), isNull);
    });

    test('rejects traversal and malformed profile identifiers', () {
      final store = ProfileStore(paths);

      for (final id in <String>[
        '../settings',
        '..\\settings',
        '/tmp/profile',
        'A-profile',
        'a',
        'profile/child',
      ]) {
        expect(() => store.fileFor(id), throwsArgumentError, reason: id);
      }
    });

    test('invalid stored profiles fail closed', () async {
      final store = ProfileStore(paths);
      await paths.ensure();
      final json = testProfile(
        root: sandbox.path,
        id: 'broken-profile',
      ).toJson()
        ..['algorithmIds'] = <String>[];
      await store
          .fileFor('broken-profile')
          .writeAsString(jsonEncode(json), flush: true);

      await expectLater(
        store.load('broken-profile'),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'atomic writer replaces text without backup or temporary debris',
      () async {
        const writer = AtomicFileWriter();
        final file = File('${sandbox.path}/nested/value.txt');

        await writer.writeText(file, 'first');
        await writer.writeText(file, 'second');

        expect(await file.readAsString(), 'second');
        final names = await file.parent
            .list()
            .map((entity) => entity.uri.pathSegments.last)
            .toList();
        expect(names, <String>['value.txt']);
      },
    );

    test('atomic writer persists binary data exactly', () async {
      const writer = AtomicFileWriter();
      final file = File('${sandbox.path}/nested/value.bin');
      final bytes = <int>[0, 1, 2, 127, 128, 255];

      await writer.writeBytes(file, bytes);
      expect(await file.readAsBytes(), bytes);
    });
  });
}
