import 'dart:io';

import 'package:centra/src/tui/folder_picker.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('FolderBrowser', () {
    late Directory sandbox;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('centra-folder-picker-');
    });

    tearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    test('lists directories only and sorts them predictably', () async {
      await Directory(p.join(sandbox.path, 'zeta')).create();
      await Directory(p.join(sandbox.path, 'Alpha')).create();
      await File(p.join(sandbox.path, 'manifest.json')).writeAsString('{}');

      final snapshot = await FolderBrowser.read(sandbox.path);
      final names = snapshot.entries
          .where((entry) => !entry.isParent)
          .map((entry) => entry.name)
          .toList();

      expect(names, <String>['Alpha', 'zeta']);
      expect(snapshot.entries.where((entry) => entry.isParent), hasLength(1));
    });

    test('hides dot-directories unless explicitly enabled', () async {
      await Directory(p.join(sandbox.path, '.private')).create();
      await Directory(p.join(sandbox.path, 'visible')).create();

      final hidden = await FolderBrowser.read(sandbox.path);
      final visible = await FolderBrowser.read(sandbox.path, showHidden: true);

      expect(
        hidden.entries.map((entry) => entry.name),
        isNot(contains('.private')),
      );
      expect(visible.entries.map((entry) => entry.name), contains('.private'));
    });

    test('falls back to the nearest existing parent', () async {
      final missing = p.join(sandbox.path, 'missing', 'nested', 'folder');

      expect(
        p.normalize(FolderBrowser.nearestExisting(missing)),
        p.normalize(sandbox.path),
      );
    });

    test('parent entry navigates to the actual parent directory', () async {
      final child = await Directory(p.join(sandbox.path, 'child')).create();
      final snapshot = await FolderBrowser.read(child.path);
      final parent = snapshot.entries.singleWhere((entry) => entry.isParent);

      expect(p.normalize(parent.path), p.normalize(sandbox.path));
      expect(p.normalize(snapshot.parentPath!), p.normalize(sandbox.path));
    });

    test('all ten locales expose folder picker labels', () {
      const locales = <String>[
        'en',
        'ru',
        'uz',
        'uz-Cyrl',
        'tr',
        'kk',
        'ky',
        'tg',
        'az',
        'de',
      ];

      for (final locale in locales) {
        final strings = FolderPickerStrings.forLocale(locale);
        expect(strings.browse, isNotEmpty, reason: locale);
        expect(strings.title, isNotEmpty, reason: locale);
        expect(strings.choose, isNotEmpty, reason: locale);
        expect(strings.help, isNotEmpty, reason: locale);
      }
    });
  });
}
