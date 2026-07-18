import 'dart:io';

import 'package:centra/centra.dart';
import 'package:test/test.dart';

void main() {
  test('settings persist language and skip repeated onboarding', () async {
    final root = await Directory.systemTemp.createTemp('centra-settings-v2-');
    try {
      final paths = CentraPaths(
        configDirectory: Directory('${root.path}/config'),
        dataDirectory: Directory('${root.path}/data'),
      );
      final store = SettingsStore(paths);
      final settings = CentraSettings.defaults.copyWith(
        locale: 'ru',
        onboardingCompleted: true,
        confirmBeforeRootScan: false,
        defaultVerificationMode: VerificationMode.fast,
        lastProfileId: 'production',
      );
      await store.save(settings);
      final restored = await store.load();
      expect(restored.locale, 'ru');
      expect(restored.onboardingCompleted, isTrue);
      expect(restored.confirmBeforeRootScan, isFalse);
      expect(restored.defaultVerificationMode, VerificationMode.fast);
      expect(restored.lastProfileId, 'production');
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('version one settings migrate without losing values', () {
    final restored = CentraSettings.fromJson(const <String, Object?>{
      'schema': 'centra.settings.v1',
      'locale': 'uz',
      'theme': 'dark',
      'confirmDestructiveActions': false,
    });
    expect(restored.locale, 'uz');
    expect(restored.theme, 'dark');
    expect(restored.confirmDestructiveActions, isFalse);
    expect(restored.onboardingCompleted, isFalse);
    expect(restored.defaultVerificationMode, VerificationMode.full);
  });
}
