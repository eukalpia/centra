import 'dart:io';

import '../util/json.dart';
import 'manifest.dart';
import 'profile.dart';
import 'services.dart';

class TrustedBaselineVerification {
  const TrustedBaselineVerification({
    required this.manifest,
    required this.signature,
    required this.signatureValid,
    required this.publicKeyTrusted,
    required this.signer,
    required this.commit,
    required this.build,
  });

  final CentraManifest manifest;
  final ManifestSignatureDocument signature;
  final bool signatureValid;
  final bool publicKeyTrusted;
  final String? signer;
  final String? commit;
  final String? build;

  bool get trusted => signatureValid && publicKeyTrusted;

  Map<String, Object?> toManifestMetadata() => <String, Object?>{
        'signatureValid': signatureValid,
        'publicKeyTrusted': publicKeyTrusted,
        'trusted': trusted,
        'keyId': signature.keyId,
        'manifestId': manifest.id,
        if (signer != null) 'signer': signer,
        if (commit != null) 'commit': commit,
        if (build != null) 'build': build,
      };
}

class TrustedBaselineService {
  TrustedBaselineService({
    ManifestCodec codec = const ManifestCodec(),
    SignatureService? signatures,
  })  : _codec = codec,
        _signatures = signatures ?? SignatureService();

  final ManifestCodec _codec;
  final SignatureService _signatures;

  Future<TrustedBaselineVerification?> loadForProfile(
    CentraProfile profile,
  ) async {
    final manifestPath = profile.trustedBaselineManifest;
    final signaturePath = profile.trustedBaselineSignature;
    final publicKeyPath = profile.trustedPublicKey;
    if (manifestPath == null && signaturePath == null && publicKeyPath == null) {
      return null;
    }
    if (manifestPath == null || signaturePath == null || publicKeyPath == null) {
      throw const FormatException(
        'Trusted baseline requires manifest, signature, and public key files.',
      );
    }
    return verifyFiles(
      manifestFile: File(manifestPath),
      signatureFile: File(signaturePath),
      publicKeyFile: File(publicKeyPath),
      signer: profile.trustedSigner,
      commit: profile.releaseCommit,
      build: profile.releaseBuild,
    );
  }

  Future<TrustedBaselineVerification> verifyFiles({
    required File manifestFile,
    required File signatureFile,
    required File publicKeyFile,
    String? signer,
    String? commit,
    String? build,
  }) async {
    for (final file in <File>[manifestFile, signatureFile, publicKeyFile]) {
      if (!await file.exists()) {
        throw FileSystemException(
          'Trusted baseline file does not exist.',
          file.path,
        );
      }
    }
    final manifest = await _codec.read(manifestFile);
    final signature = ManifestSignatureDocument.fromJson(
      decodeJsonObject(await signatureFile.readAsString()),
    );
    final trustedPublicKey = _signatures.decodePublicKey(
      await publicKeyFile.readAsString(),
    );
    final signatureValid = await _signatures.verify(
      manifest,
      signature,
      publicKey: trustedPublicKey,
    );
    final publicKeyTrusted = constantTimeBytesEqual(
      trustedPublicKey,
      signature.publicKey,
    );
    if (!signatureValid || !publicKeyTrusted) {
      throw const FormatException(
        'Trusted baseline signature or public key verification failed.',
      );
    }
    return TrustedBaselineVerification(
      manifest: manifest,
      signature: signature,
      signatureValid: signatureValid,
      publicKeyTrusted: publicKeyTrusted,
      signer: signer,
      commit: commit,
      build: build,
    );
  }
}

bool constantTimeBytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
