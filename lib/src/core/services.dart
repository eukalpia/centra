import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../util/json.dart';
import 'manifest.dart';
import 'profile.dart';
import 'storage.dart';

class ManifestCodec {
  const ManifestCodec();

  CentraManifest decode(String source) => CentraManifest.fromJson(decodeJsonObject(source));

  Future<CentraManifest> read(File file) async => decode(await file.readAsString());

  Future<void> write(File file, CentraManifest manifest, {bool pretty = true}) async {
    await const AtomicFileWriter().writeText(
      file,
      '${pretty ? manifest.encodePretty() : manifest.encodeCanonical()}\n',
    );
  }
}

class OutputArtifact {
  const OutputArtifact({
    required this.kind,
    required this.file,
    required this.bytes,
  });

  final String kind;
  final File file;
  final int bytes;
}

class ScanArtifacts {
  const ScanArtifacts({
    required this.artifacts,
    this.archive,
  });

  final List<OutputArtifact> artifacts;
  final OutputArtifact? archive;
}

class OutputService {
  OutputService({AtomicFileWriter writer = const AtomicFileWriter()}) : _writer = writer;

  final AtomicFileWriter _writer;

  Future<ScanArtifacts> write(
    CentraProfile profile,
    CentraManifest manifest, {
    String? zipPassword,
  }) async {
    final directory = Directory(profile.output.directory).absolute;
    await directory.create(recursive: true);
    final baseName = _safeBaseName('${profile.id}-${manifest.generatedAt.toUtc().toIso8601String()}');
    final artifacts = <OutputArtifact>[];

    if (profile.output.writeCanonicalJson) {
      final file = File(p.join(directory.path, '$baseName.centra.json'));
      final content = '${manifest.encodePretty()}\n';
      await _writer.writeText(file, content);
      artifacts.add(OutputArtifact(kind: 'manifest', file: file, bytes: utf8.encode(content).length));
    }

    if (profile.output.writeCompatibilityText) {
      final multiple = manifest.algorithms.length > 1;
      for (final algorithm in manifest.algorithms) {
        final fileName = multiple ? 'hash_values.${algorithm.id}.txt' : 'hash_values.txt';
        final file = File(p.join(directory.path, fileName));
        final content = _compatibilityText(manifest, algorithm.id);
        await _writer.writeText(file, content);
        artifacts.add(OutputArtifact(kind: 'compatibility:${algorithm.id}', file: file, bytes: utf8.encode(content).length));
      }
    }

    if (profile.output.includeMetadataReport) {
      final file = File(p.join(directory.path, '$baseName.report.json'));
      final content = '${prettyJson(_report(profile, manifest))}\n';
      await _writer.writeText(file, content);
      artifacts.add(OutputArtifact(kind: 'report', file: file, bytes: utf8.encode(content).length));
    }

    OutputArtifact? zipArtifact;
    if (profile.output.createZip) {
      if (profile.output.requireZipPassword && (zipPassword == null || zipPassword.isEmpty)) {
        throw StateError('This profile requires a ZIP password.');
      }
      final archive = Archive();
      for (final artifact in artifacts) {
        archive.add(ArchiveFile.bytes(p.basename(artifact.file.path), await artifact.file.readAsBytes()));
      }
      final zipBytes = ZipEncoder(password: zipPassword).encodeBytes(archive);
      final zipFile = File(p.join(directory.path, '$baseName.zip'));
      await _writer.writeBytes(zipFile, zipBytes);
      zipArtifact = OutputArtifact(kind: 'zip', file: zipFile, bytes: zipBytes.length);
    }
    return ScanArtifacts(artifacts: artifacts, archive: zipArtifact);
  }

  String _compatibilityText(CentraManifest manifest, String algorithmId) {
    final buffer = StringBuffer();
    for (final file in manifest.files) {
      final digest = file.digests[algorithmId];
      if (digest == null) continue;
      buffer
        ..write(digest)
        ..write('  ')
        ..writeln(file.path);
    }
    return buffer.toString();
  }

  Map<String, Object?> _report(CentraProfile profile, CentraManifest manifest) => <String, Object?>{
        'schema': 'centra.report.v1',
        'manifestId': manifest.id,
        'profile': <String, Object?>{'id': profile.id, 'name': profile.name},
        'generatedAt': manifest.generatedAt.toUtc().toIso8601String(),
        'source': manifest.source,
        'summary': <String, Object?>{
          'files': manifest.files.length,
          'bytes': manifest.totalBytes,
          'readErrors': manifest.errors.length,
        },
        'algorithms': manifest.algorithms.map((algorithm) => <String, Object?>{
              ...algorithm.toJson(),
              'securityWarningRequired': algorithm.warning != null,
            }).toList(growable: false),
        'policy': <String, Object?>{
          'includes': profile.includePatterns,
          'excludes': profile.excludePatterns,
          'symlinkPolicy': profile.symlinkPolicy.wireName,
        },
      };

  String _safeBaseName(String value) => value
      .replaceAll(':', '-')
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-')
      .replaceAll(RegExp('-+'), '-');
}

class SigningKeyDocument {
  const SigningKeyDocument({
    required this.id,
    required this.privateKey,
    required this.publicKey,
    required this.createdAt,
  });

  final String id;
  final List<int> privateKey;
  final List<int> publicKey;
  final DateTime createdAt;

  Map<String, Object?> toPrivateJson() => <String, Object?>{
        'schema': 'centra.ed25519.private.v1',
        'id': id,
        'algorithm': 'Ed25519',
        'privateKey': base64Encode(privateKey),
        'publicKey': base64Encode(publicKey),
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  Map<String, Object?> toPublicJson() => <String, Object?>{
        'schema': 'centra.ed25519.public.v1',
        'id': id,
        'algorithm': 'Ed25519',
        'publicKey': base64Encode(publicKey),
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

class ManifestSignatureDocument {
  const ManifestSignatureDocument({
    required this.keyId,
    required this.manifestId,
    required this.signature,
    required this.publicKey,
    required this.signedAt,
  });

  final String keyId;
  final String manifestId;
  final List<int> signature;
  final List<int> publicKey;
  final DateTime signedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 'centra.signature.v1',
        'algorithm': 'Ed25519',
        'keyId': keyId,
        'manifestId': manifestId,
        'signature': base64Encode(signature),
        'publicKey': base64Encode(publicKey),
        'signedAt': signedAt.toUtc().toIso8601String(),
      };

  factory ManifestSignatureDocument.fromJson(Map<String, Object?> json) {
    if (json['schema'] != 'centra.signature.v1' || json['algorithm'] != 'Ed25519') {
      throw const FormatException('Unsupported signature document.');
    }
    return ManifestSignatureDocument(
      keyId: json['keyId']! as String,
      manifestId: json['manifestId']! as String,
      signature: base64Decode(json['signature']! as String),
      publicKey: base64Decode(json['publicKey']! as String),
      signedAt: DateTime.parse(json['signedAt']! as String),
    );
  }
}

class SignatureService {
  SignatureService({
    Ed25519? algorithm,
    AtomicFileWriter writer = const AtomicFileWriter(),
    DateTime Function()? clock,
  })  : _algorithm = algorithm ?? Ed25519(),
        _writer = writer,
        _clock = clock ?? DateTime.now;

  final Ed25519 _algorithm;
  final AtomicFileWriter _writer;
  final DateTime Function() _clock;

  Future<SigningKeyDocument> generate(String id) async {
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{1,127}$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Invalid key ID.');
    }
    final keyPair = await _algorithm.newKeyPair();
    final privateData = await keyPair.extract();
    final publicKey = await keyPair.extractPublicKey();
    try {
      return SigningKeyDocument(
        id: id,
        privateKey: List<int>.from(privateData.bytes),
        publicKey: List<int>.from(publicKey.bytes),
        createdAt: _clock().toUtc(),
      );
    } finally {
      privateData.destroy();
      keyPair.destroy();
    }
  }

  Future<void> writeKeyPair(SigningKeyDocument key, File privateFile, File publicFile) async {
    await _writer.writeText(privateFile, '${prettyJson(key.toPrivateJson())}\n');
    await _writer.writeText(publicFile, '${prettyJson(key.toPublicJson())}\n');
    if (!Platform.isWindows) {
      final result = await Process.run('chmod', <String>['600', privateFile.path], runInShell: false);
      if (result.exitCode != 0) {
        throw FileSystemException('Unable to restrict private key permissions.', privateFile.path);
      }
    }
  }

  Future<ManifestSignatureDocument> sign(CentraManifest manifest, SigningKeyDocument key) async {
    final publicKey = SimplePublicKey(key.publicKey, type: KeyPairType.ed25519);
    final keyPair = SimpleKeyPairData(
      key.privateKey,
      publicKey: publicKey,
      type: KeyPairType.ed25519,
    );
    try {
      final signature = await _algorithm.sign(
        utf8.encode(manifest.encodeCanonical()),
        keyPair: keyPair,
      );
      final signaturePublicKey = signature.publicKey;
      if (signaturePublicKey is! SimplePublicKey) {
        throw StateError('Ed25519 returned an unsupported public key type.');
      }
      return ManifestSignatureDocument(
        keyId: key.id,
        manifestId: manifest.id,
        signature: List<int>.from(signature.bytes),
        publicKey: List<int>.from(signaturePublicKey.bytes),
        signedAt: _clock().toUtc(),
      );
    } finally {
      keyPair.destroy();
    }
  }

  Future<bool> verify(CentraManifest manifest, ManifestSignatureDocument document, {List<int>? publicKey}) async {
    if (document.manifestId != manifest.id) return false;
    final key = SimplePublicKey(publicKey ?? document.publicKey, type: KeyPairType.ed25519);
    final signature = Signature(document.signature, publicKey: key);
    return _algorithm.verify(utf8.encode(manifest.encodeCanonical()), signature: signature);
  }

  SigningKeyDocument decodePrivateKey(String source) {
    final json = decodeJsonObject(source);
    if (json['schema'] != 'centra.ed25519.private.v1' || json['algorithm'] != 'Ed25519') {
      throw const FormatException('Unsupported private key document.');
    }
    return SigningKeyDocument(
      id: json['id']! as String,
      privateKey: base64Decode(json['privateKey']! as String),
      publicKey: base64Decode(json['publicKey']! as String),
      createdAt: DateTime.parse(json['createdAt']! as String),
    );
  }

  List<int> decodePublicKey(String source) {
    final json = decodeJsonObject(source);
    if (json['schema'] != 'centra.ed25519.public.v1' || json['algorithm'] != 'Ed25519') {
      throw const FormatException('Unsupported public key document.');
    }
    return base64Decode(json['publicKey']! as String);
  }
}
