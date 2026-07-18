import 'dart:io';

import 'package:centra/centra.dart';
import 'package:test/test.dart';

void main() {
  test('accepts a manifest signed by the configured trusted key', () async {
    final root = await Directory.systemTemp.createTemp('centra-baseline-');
    try {
      final manifest = _manifest();
      final signatures = SignatureService(
        clock: () => DateTime.utc(2026, 7, 18, 12),
      );
      final key = await signatures.generate('production-release');
      final signature = await signatures.sign(manifest, key);
      final manifestFile = File('${root.path}/baseline.centra.json');
      final signatureFile = File('${root.path}/baseline.signature.json');
      final publicFile = File('${root.path}/production-release.public.json');
      final privateFile = File('${root.path}/production-release.private.json');
      await const ManifestCodec().write(manifestFile, manifest);
      await signatureFile.writeAsString(
        '${prettyCentraJson(signature.toJson())}\n',
      );
      await signatures.writeKeyPair(key, privateFile, publicFile);

      final verified = await TrustedBaselineService().verifyFiles(
        manifestFile: manifestFile,
        signatureFile: signatureFile,
        publicKeyFile: publicFile,
        signer: 'release-engineering',
        commit: 'a93f6b2',
        build: '184',
      );
      expect(verified.trusted, isTrue);
      expect(verified.toManifestMetadata()['commit'], 'a93f6b2');
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('rejects a signature when another public key is trusted', () async {
    final root = await Directory.systemTemp.createTemp('centra-baseline-');
    try {
      final manifest = _manifest();
      final signatures = SignatureService();
      final signingKey = await signatures.generate('signing');
      final otherKey = await signatures.generate('other');
      final signature = await signatures.sign(manifest, signingKey);
      final manifestFile = File('${root.path}/baseline.json');
      final signatureFile = File('${root.path}/signature.json');
      final publicFile = File('${root.path}/other.public.json');
      final privateFile = File('${root.path}/other.private.json');
      await const ManifestCodec().write(manifestFile, manifest);
      await signatureFile.writeAsString(
        '${prettyCentraJson(signature.toJson())}\n',
      );
      await signatures.writeKeyPair(otherKey, privateFile, publicFile);

      await expectLater(
        TrustedBaselineService().verifyFiles(
          manifestFile: manifestFile,
          signatureFile: signatureFile,
          publicKeyFile: publicFile,
        ),
        throwsFormatException,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });
}

CentraManifest _manifest() => CentraManifest(
      id: 'baseline-1',
      generatedAt: DateTime.utc(2026, 7, 18),
      toolVersion: '0.2.0',
      profileId: 'prod',
      profileName: 'Production',
      projectKind: 'generic',
      source: const <String, Object?>{'type': 'local', 'root': '/srv/app'},
      algorithms: const <HashAlgorithmDescriptor>[
        HashAlgorithmDescriptor(
          id: 'sha256',
          label: 'SHA-256',
          family: 'SHA-2',
          outputBits: 256,
          security: AlgorithmSecurity.recommended,
        ),
      ],
      includePatterns: const <String>['**'],
      excludePatterns: const <String>[],
      files: const <ManifestFileRecord>[
        ManifestFileRecord(
          path: 'app.bin',
          size: 3,
          digests: <String, String>{
            'sha256':
                'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
          },
        ),
      ],
      errors: const <ManifestReadError>[],
      totalBytes: 3,
    );

String prettyCentraJson(Map<String, Object?> value) {
  final buffer = StringBuffer('{\n');
  final entries = value.entries.toList();
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    buffer
      ..write('  "${entry.key}": ')
      ..write(_jsonValue(entry.value));
    if (index + 1 < entries.length) buffer.write(',');
    buffer.writeln();
  }
  buffer.write('}');
  return buffer.toString();
}

String _jsonValue(Object? value) {
  if (value == null) return 'null';
  if (value is bool || value is num) return value.toString();
  if (value is String) {
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
  }
  if (value is List) return '[${value.map(_jsonValue).join(',')}]';
  if (value is Map) {
    return '{${value.entries.map((entry) => '${_jsonValue(entry.key.toString())}:${_jsonValue(entry.value)}').join(',')}}';
  }
  throw ArgumentError.value(value);
}
