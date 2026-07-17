import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../util/json.dart';
import 'profile.dart';

class CentraPaths {
  CentraPaths({Directory? configDirectory, Directory? dataDirectory})
      : configDirectory = configDirectory ?? _defaultConfigDirectory(),
        dataDirectory = dataDirectory ?? _defaultDataDirectory();

  final Directory configDirectory;
  final Directory dataDirectory;

  Directory get profilesDirectory =>
      Directory(p.join(configDirectory.path, 'profiles'));
  File get settingsFile => File(p.join(configDirectory.path, 'settings.json'));
  Directory get historyDirectory =>
      Directory(p.join(dataDirectory.path, 'history'));

  Future<void> ensure() async {
    await configDirectory.create(recursive: true);
    await profilesDirectory.create(recursive: true);
    await dataDirectory.create(recursive: true);
    await historyDirectory.create(recursive: true);
  }

  static Directory _defaultConfigDirectory() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      return Directory(p.join(
          appData ?? Platform.environment['USERPROFILE'] ?? '.', 'Centra'));
    }
    if (Platform.isMacOS) {
      return Directory(
          p.join(_home(), 'Library', 'Application Support', 'Centra'));
    }
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    return Directory(p.join(xdg ?? p.join(_home(), '.config'), 'centra'));
  }

  static Directory _defaultDataDirectory() {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      return Directory(p.join(
          localAppData ?? Platform.environment['APPDATA'] ?? '.', 'Centra'));
    }
    if (Platform.isMacOS) {
      return Directory(
          p.join(_home(), 'Library', 'Application Support', 'Centra'));
    }
    final xdg = Platform.environment['XDG_DATA_HOME'];
    return Directory(
        p.join(xdg ?? p.join(_home(), '.local', 'share'), 'centra'));
  }

  static String _home() =>
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
}

class CentraSettings {
  const CentraSettings({
    required this.locale,
    required this.theme,
    required this.confirmDestructiveActions,
  });

  final String locale;
  final String theme;
  final bool confirmDestructiveActions;

  static const defaults = CentraSettings(
    locale: 'en',
    theme: 'auto',
    confirmDestructiveActions: true,
  );

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 'centra.settings.v1',
        'locale': locale,
        'theme': theme,
        'confirmDestructiveActions': confirmDestructiveActions,
      };

  factory CentraSettings.fromJson(Map<String, Object?> json) {
    if (json['schema'] != 'centra.settings.v1') {
      throw FormatException('Unsupported settings schema: ${json['schema']}');
    }
    return CentraSettings(
      locale: json['locale'] as String? ?? 'en',
      theme: json['theme'] as String? ?? 'auto',
      confirmDestructiveActions:
          json['confirmDestructiveActions'] as bool? ?? true,
    );
  }
}

class AtomicFileWriter {
  const AtomicFileWriter();

  Future<void> writeText(File file, String content) async {
    await file.parent.create(recursive: true);
    final temporary =
        File('${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}');
    await temporary.writeAsString(content, encoding: utf8, flush: true);
    if (await file.exists()) {
      final backup = File('${file.path}.bak');
      if (await backup.exists()) await backup.delete();
      await file.rename(backup.path);
      try {
        await temporary.rename(file.path);
        await backup.delete();
      } catch (_) {
        if (!await file.exists() && await backup.exists())
          await backup.rename(file.path);
        rethrow;
      }
    } else {
      await temporary.rename(file.path);
    }
  }

  Future<void> writeBytes(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final temporary =
        File('${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}

class SettingsStore {
  SettingsStore(this.paths,
      {AtomicFileWriter writer = const AtomicFileWriter()})
      : _writer = writer;

  final CentraPaths paths;
  final AtomicFileWriter _writer;

  Future<CentraSettings> load() async {
    await paths.ensure();
    if (!await paths.settingsFile.exists()) return CentraSettings.defaults;
    final json = decodeJsonObject(await paths.settingsFile.readAsString());
    return CentraSettings.fromJson(json);
  }

  Future<void> save(CentraSettings settings) async {
    await paths.ensure();
    await _writer.writeText(
        paths.settingsFile, '${prettyJson(settings.toJson())}\n');
  }
}

class ProfileStore {
  ProfileStore(this.paths, {AtomicFileWriter writer = const AtomicFileWriter()})
      : _writer = writer;

  final CentraPaths paths;
  final AtomicFileWriter _writer;

  File fileFor(String id) =>
      File(p.join(paths.profilesDirectory.path, '$id.json'));

  Future<List<CentraProfile>> list() async {
    await paths.ensure();
    final profiles = <CentraProfile>[];
    await for (final entity in paths.profilesDirectory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      profiles.add(await loadFile(entity));
    }
    profiles.sort((left, right) =>
        left.name.toLowerCase().compareTo(right.name.toLowerCase()));
    return profiles;
  }

  Future<CentraProfile?> load(String id) async {
    final file = fileFor(id);
    if (!await file.exists()) return null;
    return loadFile(file);
  }

  Future<CentraProfile> loadFile(File file) async {
    final json = decodeJsonObject(await file.readAsString());
    final profile = CentraProfile.fromJson(json);
    final errors = profile.validate();
    if (errors.isNotEmpty) {
      throw FormatException(
          'Invalid profile ${file.path}:\n${errors.join('\n')}');
    }
    return profile;
  }

  Future<void> save(CentraProfile profile) async {
    final errors = profile.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    await paths.ensure();
    await _writer.writeText(
        fileFor(profile.id), '${prettyJson(profile.toJson())}\n');
  }

  Future<bool> delete(String id) async {
    final file = fileFor(id);
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }
}
