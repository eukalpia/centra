import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:centra/centra.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('ManifestCodec', () {
    test('writes and reads a deterministic manifest document', () async {
      final directory =
          await Directory.systemTemp.createTemp('centra-codec-test-');
      try {
        final file = File('${directory.path}/manifest.json');
        final manifest = testManifest();
        const codec = ManifestCodec();

        await codec.write(file, manifest);
        final decoded = await codec.read(file);

        expect(decoded.encodeCanonical(), manifest.encodeCanonical());
        expect(await file.readAsString(), endsWith('\n'));
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });

  group('OutputService', () {
    late Directory sandbox;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('centra-output-test-');
    });

    tearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    test('writes canonical, compatibility, report and encrypted ZIP outputs',
        () async {
      final outputDirectory = Directory('${sandbox.path}/output');
      final profile = testProfile(
        root: sandbox.path,
        algorithmIds: const <String>['sha256', 'md5'],
        output: OutputConfig(
          directory: outputDirectory.path,
          writeCanonicalJson: true,
          writeCompatibilityText: true,
          createZip: true,
          requireZipPassword: true,
          includeMetadataReport: true,
        ),
      );
      final registry = AlgorithmRegistry();
      final manifest = testManifest(
        algorithms: <HashAlgorithmDescriptor>[
          registry.descriptor('sha256'),
          registry.descriptor('md5'),
        ],
        files: const <ManifestFileRecord>[
          ManifestFileRecord(
            path: 'lib/main.dart',
            size: 3,
            digests: <String, String>{
              'sha256': 'sha256-value',
              'md5': 'md5-value',
            },
          ),
        ],
      );

      final result = await OutputService()
          .write(profile, manifest, zipPassword: 'correct horse battery staple');

      expect(result.artifacts.map((artifact) => artifact.kind), containsAll(
        <String>['manifest', 'compatibility:sha256', 'compatibility:md5', 'report'],
      ));
      expect(result.archive, isNotNull);
      expect(await result.archive!.file.exists(), isTrue);

      final shaText =
          await File('${outputDirectory.path}/hash_values.sha256.txt')
              .readAsString();
      final md5Text = await File('${outputDirectory.path}/hash_values.md5.txt')
          .readAsString();
      expect(shaText, 'sha256-value  lib/main.dart\n');
      expect(md5Text, 'md5-value  lib/main.dart\n');

      final reportFile = result.artifacts
          .singleWhere((artifact) => artifact.kind == 'report')
          .file;
      final report = jsonDecode(await reportFile.readAsString())
          as Map<String, dynamic>;
      final algorithms = (report['algorithms'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final md5 = algorithms.singleWhere((entry) => entry['id'] == 'md5');
      expect(md5['status'], 'obsolete');
      expect(md5['securityWarningRequired'], isTrue);

      final archive = ZipDecoder().decodeBytes(
        await result.archive!.file.readAsBytes(),
        password: 'correct horse battery staple',
      );
      final names = archive.map((entry) => entry.name).toSet();
      expect(names, contains('hash_values.sha256.txt'));
      expect(names, contains('hash_values.md5.txt'));
      expect(names.any((name) => name.endsWith('.centra.json')), isTrue);
      expect(names.any((name) => name.endsWith('.report.json')), isTrue);
    });

    test('refuses a required encrypted archive without a password', () async {
      final profile = testProfile(
        root: sandbox.path,
        output: OutputConfig(
          directory: '${sandbox.path}/output',
          writeCanonicalJson: true,
          writeCompatibilityText: false,
          createZip: true,
          requireZipPassword: true,
          includeMetadataReport: false,
        ),
      );

      await expectLater(
        OutputService().write(profile, testManifest()),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('SignatureService', () {
    final fixed = DateTime.utc(2026, 7, 17, 12);

    test('generates, signs and verifies an Ed25519 manifest signature',
        () async {
      final service = SignatureService(clock: () => fixed);
      final key = await service.generate('release-key');
      final manifest = testManifest();
      final document = await service.sign(manifest, key);

      expect(key.createdAt, fixed);
      expect(document.signedAt, fixed);
      expect(document.keyId, 'release-key');
      expect(document.manifestId, manifest.id);
      expect(await service.verify(manifest, document), isTrue);
    });

    test('rejects a signature after manifest content changes', () async {
      final service = SignatureService(clock: () => fixed);
      final key = await service.generate('release-key');
      final original = testManifest();
      final document = await service.sign(original, key);
      final changed = testManifest(
        id: original.id,
        files: const <ManifestFileRecord>[
          ManifestFileRecord(
            path: 'lib/main.dart',
            size: 4,
            digests: <String, String>{'sha256': 'changed'},
          ),
        ],
      );

      expect(await service.verify(changed, document), isFalse);
    });

    test('rejects a trusted public key from another key pair', () async {
      final service = SignatureService(clock: () => fixed);
      final signer = await service.generate('signer-key');
      final other = await service.generate('other-key');
      final manifest = testManifest();
      final document = await service.sign(manifest, signer);

      expect(
        await service.verify(manifest, document, publicKey: other.publicKey),
        isFalse,
      );
    });

    test('private and public key documents round-trip', () async {
      final directory =
          await Directory.systemTemp.createTemp('centra-key-test-');
      try {
        final service = SignatureService(clock: () => fixed);
        final key = await service.generate('release-key');
        final privateFile = File('${directory.path}/release.private.json');
        final publicFile = File('${directory.path}/release.public.json');

        await service.writeKeyPair(key, privateFile, publicFile);
        final decodedPrivate =
            service.decodePrivateKey(await privateFile.readAsString());
        final decodedPublic =
            service.decodePublicKey(await publicFile.readAsString());

        expect(decodedPrivate.id, key.id);
        expect(decodedPrivate.privateKey, key.privateKey);
        expect(decodedPrivate.publicKey, key.publicKey);
        expect(decodedPublic, key.publicKey);
        if (!Platform.isWindows) {
          final mode = (await privateFile.stat()).mode & 0x1ff;
          expect(mode, 0x180);
        }
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('rejects malformed key IDs and unsupported signature schemas', () async {
      final service = SignatureService(clock: () => fixed);

      await expectLater(service.generate('../key'), throwsArgumentError);
      expect(
        () => ManifestSignatureDocument.fromJson(<String, Object?>{
          'schema': 'unknown',
          'algorithm': 'Ed25519',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
