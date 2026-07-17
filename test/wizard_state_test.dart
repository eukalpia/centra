import 'package:centra/src/core/profile.dart';
import 'package:centra/src/tui/wizard_state.dart';
import 'package:test/test.dart';

void main() {
  group('WizardDraft', () {
    test('starts without hidden policy selections', () {
      final draft = WizardDraft();
      expect(draft.locale, isNull);
      expect(draft.sourceType, isNull);
      expect(draft.algorithmIds, isEmpty);
      expect(draft.canonicalJson, isFalse);
      expect(draft.compatibilityText, isFalse);
      expect(draft.zipPackage, isFalse);
      expect(draft.metadataReport, isFalse);
    });

    test('blocks every required step until the user makes a choice', () {
      final draft = WizardDraft();
      expect(draft.canContinue(WizardStep.language), isFalse);
      expect(draft.canContinue(WizardStep.source), isFalse);
      expect(draft.canContinue(WizardStep.algorithms), isFalse);
      expect(draft.canContinue(WizardStep.output), isFalse);
    });

    test('creates a complete profile after explicit choices', () {
      final fixed = DateTime.utc(2026, 7, 17, 12);
      final draft = WizardDraft(clock: () => fixed)
        ..locale = 'ru'
        ..sourceType = SourceType.local
        ..profileName = 'Production'
        ..profileId = 'production'
        ..root = '/srv/application'
        ..algorithmIds.addAll(const <String>['sha256', 'md5'])
        ..excludePatterns.addAll(const <String>{'.git/**', '**/.env'})
        ..canonicalJson = true
        ..compatibilityText = true
        ..outputDirectory = '/secure/output';

      for (final step in WizardStep.values) {
        expect(draft.validateStep(step), isEmpty, reason: step.name);
      }
      final profile = draft.toProfile();
      expect(profile.locale, 'ru');
      expect(profile.algorithmIds, containsAllInOrder(<String>['sha256', 'md5']));
      expect(profile.createdAt, fixed);
      expect(profile.validate(), isEmpty);
    });

    test('requires ZIP mode before a password requirement can be serialized', () {
      final draft = WizardDraft()
        ..locale = 'en'
        ..sourceType = SourceType.local
        ..profileName = 'Test'
        ..profileId = 'test-profile'
        ..root = '/tmp/project'
        ..algorithmIds.add('sha256')
        ..canonicalJson = true
        ..outputDirectory = '/tmp/output'
        ..requireZipPassword = true;
      final profile = draft.toProfile();
      expect(profile.output.createZip, isFalse);
      expect(profile.output.requireZipPassword, isFalse);
    });
  });
}
