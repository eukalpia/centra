import 'package:centra/centra.dart';
import 'package:test/test.dart';

void main() {
  group('SSH configuration', () {
    test('password authentication does not require a private key', () {
      const config = SourceConfig(
        type: SourceType.ssh,
        root: '/srv/application',
        host: '195.158.3.42',
        user: 'deploy',
        port: 2862,
        sshAuthMethod: SshAuthMethod.password,
        sshHostKeyPolicy: SshHostKeyPolicy.pinned,
        hostKeyType: 'ssh-ed25519',
        hostKeyFingerprint: 'SHA256:test-fingerprint',
      );

      expect(config.validate(), isEmpty);
    });

    test('private-key authentication requires an identity file', () {
      const config = SourceConfig(
        type: SourceType.ssh,
        root: '/srv/application',
        host: 'server.example.com',
        user: 'deploy',
        sshAuthMethod: SshAuthMethod.privateKey,
        sshHostKeyPolicy: SshHostKeyPolicy.pinned,
        hostKeyFingerprint: 'SHA256:test-fingerprint',
      );

      expect(
        config.validate(),
        contains('SSH private key file is required.'),
      );
    });

    test('saved SSH profiles require a pinned host fingerprint', () {
      const config = SourceConfig(
        type: SourceType.ssh,
        root: '/srv/application',
        host: 'server.example.com',
        user: 'deploy',
        sshAuthMethod: SshAuthMethod.password,
      );

      expect(
        config.validate(),
        contains('SSH host key fingerprint is required.'),
      );
    });

    test('SSH settings round-trip without serializing secrets', () {
      const config = SourceConfig(
        type: SourceType.ssh,
        root: '/opt/service',
        host: 'server.example.com',
        user: 'release',
        port: 2222,
        identityFile: '~/.ssh/release_ed25519',
        sshAuthMethod: SshAuthMethod.passwordAndKey,
        sshHostKeyPolicy: SshHostKeyPolicy.pinned,
        hostKeyType: 'ssh-ed25519',
        hostKeyFingerprint: 'SHA256:known-host-key',
        connectTimeoutSeconds: 25,
        keepAliveSeconds: 30,
      );

      final json = config.toJson();
      final restored = SourceConfig.fromJson(json);

      expect(json, isNot(contains('password')));
      expect(json, isNot(contains('keyPassphrase')));
      expect(restored.type, SourceType.ssh);
      expect(restored.root, '/opt/service');
      expect(restored.host, 'server.example.com');
      expect(restored.user, 'release');
      expect(restored.port, 2222);
      expect(restored.sshAuthMethod, SshAuthMethod.passwordAndKey);
      expect(restored.sshHostKeyPolicy, SshHostKeyPolicy.pinned);
      expect(restored.hostKeyType, 'ssh-ed25519');
      expect(restored.hostKeyFingerprint, 'SHA256:known-host-key');
      expect(restored.connectTimeoutSeconds, 25);
      expect(restored.keepAliveSeconds, 30);
    });

    test('connection timing limits are validated', () {
      const config = SourceConfig(
        type: SourceType.ssh,
        root: '/srv/application',
        host: 'server.example.com',
        user: 'deploy',
        sshAuthMethod: SshAuthMethod.password,
        hostKeyFingerprint: 'SHA256:test-fingerprint',
        connectTimeoutSeconds: 0,
        keepAliveSeconds: -1,
      );

      expect(
        config.validate(),
        containsAll(<String>[
          'SSH timeout must be between 1 and 300 seconds.',
          'SSH keepalive must be between 0 and 3600 seconds.',
        ]),
      );
    });
  });

  group('SSH secrets', () {
    test('secret presence is explicit and remains transient', () {
      const empty = SshConnectionSecrets();
      const populated = SshConnectionSecrets(
        password: 'temporary-password',
        keyPassphrase: 'temporary-passphrase',
      );

      expect(empty.hasPassword, isFalse);
      expect(empty.hasKeyPassphrase, isFalse);
      expect(populated.hasPassword, isTrue);
      expect(populated.hasKeyPassphrase, isTrue);
    });
  });

  group('SSH paths', () {
    test('normalizes remote paths as absolute POSIX paths', () {
      expect(normalizeSshPath('srv\\application'), '/srv/application');
      expect(normalizeSshPath('/srv/../opt/service'), '/opt/service');
      expect(normalizeSshPath(''), '/');
    });

    test('calculates parents without escaping the remote root', () {
      expect(sshParentPath('/srv/application'), '/srv');
      expect(sshParentPath('/srv'), '/');
      expect(sshParentPath('/'), isNull);
    });
  });
}
