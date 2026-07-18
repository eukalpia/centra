import 'dart:io';

import 'package:centra/centra.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late CentraPaths paths;
  late SshConnectionStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('centra-ssh-library-test-');
    paths = CentraPaths(
      configDirectory: Directory('${root.path}/config'),
      dataDirectory: Directory('${root.path}/data'),
    );
    store = SshConnectionStore(
      paths,
      clock: () => DateTime.utc(2026, 7, 18, 10),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('creates, loads, duplicates and deletes named connections', () async {
    final first = await store.create(
      name: 'Production API',
      host: 'server.example.com',
      port: 2862,
      user: 'deploy',
      authMethod: SshAuthMethod.password,
      lastPath: '/srv/api',
    );
    expect(first.id, 'production-api');
    expect((await store.load(first.id))?.endpoint,
        'deploy@server.example.com:2862');

    final copy = await store.duplicate(first.id, name: 'Production API copy');
    expect(copy.id, 'production-api-copy');
    expect(await store.list(), hasLength(2));
    expect(await store.delete(first.id), isTrue);
    expect(await store.load(first.id), isNull);
  });

  test('serialized library never contains passwords or passphrases', () async {
    await store.create(
      name: 'Private server',
      host: 'private.example.com',
      port: 22,
      user: 'release',
      authMethod: SshAuthMethod.privateKey,
      identityFile: '~/.ssh/release_ed25519',
    );
    final source = await paths.sshConnectionsFile.readAsString();
    expect(source, isNot(contains('password')));
    expect(source, isNot(contains('passphrase')));
    expect(source, contains('private.example.com'));
  });

  test('successful connection records pinned host and last directory', () async {
    final created = await store.create(
      name: 'Web',
      host: 'web.example.com',
      port: 22,
      user: 'deploy',
      authMethod: SshAuthMethod.password,
    );
    await store.recordSuccessfulConnection(
      connection: created,
      path: '/var/www/site',
      hostKeyType: 'ssh-ed25519',
      hostKeyFingerprint: 'SHA256:test',
    );
    final restored = await store.load(created.id);
    expect(restored?.lastPath, '/var/www/site');
    expect(restored?.hostKeyFingerprint, 'SHA256:test');
    expect(restored?.lastConnectedAt, isNotNull);
  });
}
