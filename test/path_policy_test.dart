import 'package:centra/centra.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeRelativePath', () {
    test('normalizes separators and dot segments', () {
      expect(normalizeRelativePath(r'.\lib\src\..\main.dart'), 'lib/main.dart');
    });

    test('rejects paths escaping the root', () {
      expect(() => normalizeRelativePath('../secret.env'), throwsFormatException);
      expect(() => normalizeRelativePath('/etc/passwd'), throwsFormatException);
    });
  });

  group('PathPolicy', () {
    test('matches recursive secret patterns at root and below it', () {
      final policy = PathPolicy(
        includes: const <String>['**'],
        excludes: const <String>['**/.env', '**/.env.*', '**/*.key'],
        includeHiddenFiles: true,
      );
      expect(policy.allows('.env'), isFalse);
      expect(policy.allows('apps/api/.env.production'), isFalse);
      expect(policy.allows('certs/signing.key'), isFalse);
      expect(policy.allows('lib/main.dart'), isTrue);
    });

    test('excludes generated dependency directories', () {
      final policy = PathPolicy(
        includes: const <String>['**'],
        excludes: const <String>['node_modules/**', '**/node_modules/**', 'build/**'],
        includeHiddenFiles: true,
      );
      expect(policy.allows('node_modules/pkg/index.js'), isFalse);
      expect(policy.allows('apps/web/node_modules/pkg/index.js'), isFalse);
      expect(policy.allows('build/app.exe'), isFalse);
    });

    test('honors explicit include patterns', () {
      final policy = PathPolicy(
        includes: const <String>['lib/**', 'pubspec.yaml'],
        excludes: const <String>[],
        includeHiddenFiles: true,
      );
      expect(policy.allows('lib/main.dart'), isTrue);
      expect(policy.allows('pubspec.yaml'), isTrue);
      expect(policy.allows('README.md'), isFalse);
    });

    test('can suppress hidden path segments independently', () {
      final policy = PathPolicy(
        includes: const <String>['**'],
        excludes: const <String>[],
        includeHiddenFiles: false,
      );
      expect(policy.allows('.git/config'), isFalse);
      expect(policy.allows('lib/.generated/file.dart'), isFalse);
      expect(policy.allows('lib/main.dart'), isTrue);
    });
  });

  group('ProjectDetector', () {
    test('detects Flutter and suggests build exclusions', () async {
      final detection = await ProjectDetector.detect(<String>{'pubspec.yaml', 'lib', 'android', 'ios'});
      expect(detection.kind, 'flutter');
      expect(detection.suggestedExcludes, contains('.dart_tool/**'));
      expect(detection.suggestedExcludes, contains('**/.env'));
    });

    test('falls back to generic secret-safe policy', () async {
      final detection = await ProjectDetector.detect(<String>{'README.md'});
      expect(detection.kind, 'generic');
      expect(detection.suggestedExcludes, contains('**/*.pem'));
    });
  });
}
