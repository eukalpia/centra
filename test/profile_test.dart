import 'package:centra/centra.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('CentraProfile validation', () {
    test('requires an explicit algorithm selection', () {
      final profile = testProfile(root: '/tmp/project', algorithmIds: const <String>[]);
      expect(profile.validate(), contains('Select at least one hash or checksum algorithm.'));
    });

    test('requires an explicit output format', () {
      final profile = testProfile(
        root: '/tmp/project',
        output: const OutputConfig(
          directory: '/tmp/output',
          writeCanonicalJson: false,
          writeCompatibilityText: false,
          createZip: false,
          requireZipPassword: false,
          includeMetadataReport: false,
        ),
      );
      expect(profile.validate(), contains('Select at least one output format.'));
    });

    test('allows MD5 compatibility profile without hiding its status', () {
      final profile = testProfile(root: '/tmp/project', algorithmIds: const <String>['md5']);
      expect(profile.validate(), isEmpty);
      expect(AlgorithmRegistry().descriptor(profile.algorithmIds.single).status, AlgorithmStatus.obsolete);
    });

    test('validates source-specific required fields', () {
      const ssh = SourceConfig(type: SourceType.ssh, root: '/srv/app');
      expect(ssh.validate(), containsAll(<String>['SSH host is required.', 'SSH user is required.']));

      const container = SourceConfig(type: SourceType.dockerContainer, root: '/app');
      expect(container.validate(), contains('Docker container is required.'));

      const image = SourceConfig(type: SourceType.dockerImage, root: '/app');
      expect(image.validate(), contains('Docker image is required.'));

      const compose = SourceConfig(type: SourceType.dockerCompose, root: '/app');
      expect(compose.validate(), contains('Compose service is required.'));
    });

    test('round-trips through the versioned JSON schema', () {
      final original = testProfile(
        root: '/tmp/project',
        algorithmIds: const <String>['sha256', 'md5'],
        excludes: const <String>['.git/**', '**/.env'],
      );
      final decoded = CentraProfile.fromJson(original.toJson());
      expect(decoded.toJson(), original.toJson());
    });

    test('custom algorithms must use a file placeholder', () {
      const custom = CustomHashAlgorithm(
        id: 'broken-custom',
        displayName: 'Broken',
        executable: 'hash-tool',
        arguments: <String>['--stdin'],
        outputPattern: r'([0-9a-f]+)',
        outputGroup: 1,
      );
      final profile = testProfile(
        root: '/tmp/project',
        algorithmIds: const <String>['broken-custom'],
        customAlgorithms: const <CustomHashAlgorithm>[custom],
      );
      expect(profile.validate().join(' '), contains('{file}'));
    });
  });
}
