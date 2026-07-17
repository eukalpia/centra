import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../util/hex.dart';

enum AlgorithmStatus {
  recommended,
  acceptable,
  legacy,
  obsolete,
  checksum,
  custom,
}

extension AlgorithmStatusName on AlgorithmStatus {
  String get wireName => switch (this) {
        AlgorithmStatus.recommended => 'recommended',
        AlgorithmStatus.acceptable => 'acceptable',
        AlgorithmStatus.legacy => 'legacy',
        AlgorithmStatus.obsolete => 'obsolete',
        AlgorithmStatus.checksum => 'checksum',
        AlgorithmStatus.custom => 'custom',
      };

  static AlgorithmStatus parse(String value) =>
      AlgorithmStatus.values.firstWhere(
        (status) => status.wireName == value,
        orElse: () => AlgorithmStatus.custom,
      );
}

class HashAlgorithmDescriptor {
  const HashAlgorithmDescriptor({
    required this.id,
    required this.displayName,
    required this.outputBits,
    required this.status,
    required this.summary,
    this.registryName,
    this.warning,
  });

  final String id;
  final String displayName;
  final int outputBits;
  final AlgorithmStatus status;
  final String summary;
  final String? registryName;
  final String? warning;

  bool get isLegacy =>
      status == AlgorithmStatus.legacy || status == AlgorithmStatus.obsolete;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'displayName': displayName,
        'outputBits': outputBits,
        'status': status.wireName,
        'summary': summary,
        if (registryName != null) 'registryName': registryName,
        if (warning != null) 'warning': warning,
      };

  factory HashAlgorithmDescriptor.fromJson(Map<String, Object?> json) {
    return HashAlgorithmDescriptor(
      id: json['id']! as String,
      displayName: json['displayName']! as String,
      outputBits: json['outputBits']! as int,
      status: AlgorithmStatusName.parse(json['status']! as String),
      summary: json['summary']! as String,
      registryName: json['registryName'] as String?,
      warning: json['warning'] as String?,
    );
  }
}

class CustomHashAlgorithm {
  const CustomHashAlgorithm({
    required this.id,
    required this.displayName,
    required this.executable,
    required this.arguments,
    required this.outputPattern,
    required this.outputGroup,
    this.outputBits = 0,
    this.timeoutSeconds = 60,
  });

  final String id;
  final String displayName;
  final String executable;
  final List<String> arguments;
  final String outputPattern;
  final int outputGroup;
  final int outputBits;
  final int timeoutSeconds;

  HashAlgorithmDescriptor get descriptor => HashAlgorithmDescriptor(
        id: id,
        displayName: displayName,
        outputBits: outputBits,
        status: AlgorithmStatus.custom,
        summary: 'External hash command configured by the user.',
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'displayName': displayName,
        'executable': executable,
        'arguments': arguments,
        'outputPattern': outputPattern,
        'outputGroup': outputGroup,
        'outputBits': outputBits,
        'timeoutSeconds': timeoutSeconds,
      };

  factory CustomHashAlgorithm.fromJson(Map<String, Object?> json) {
    return CustomHashAlgorithm(
      id: json['id']! as String,
      displayName: json['displayName']! as String,
      executable: json['executable']! as String,
      arguments: (json['arguments']! as List<Object?>).cast<String>(),
      outputPattern: json['outputPattern']! as String,
      outputGroup: json['outputGroup']! as int,
      outputBits: json['outputBits'] as int? ?? 0,
      timeoutSeconds: json['timeoutSeconds'] as int? ?? 60,
    );
  }
}

typedef DigestFactory = Digest Function();

class AlgorithmRegistry {
  AlgorithmRegistry({Iterable<CustomHashAlgorithm> customAlgorithms = const []})
      : _customAlgorithms = <String, CustomHashAlgorithm>{
          for (final algorithm in customAlgorithms) algorithm.id: algorithm,
        };

  final Map<String, CustomHashAlgorithm> _customAlgorithms;

  static final List<HashAlgorithmDescriptor> builtIns =
      <HashAlgorithmDescriptor>[
    const HashAlgorithmDescriptor(
      id: 'sha256',
      displayName: 'SHA-256',
      outputBits: 256,
      status: AlgorithmStatus.recommended,
      registryName: 'SHA-256',
      summary: 'Widely supported modern baseline for integrity manifests.',
    ),
    const HashAlgorithmDescriptor(
      id: 'sha384',
      displayName: 'SHA-384',
      outputBits: 384,
      status: AlgorithmStatus.recommended,
      registryName: 'SHA-384',
      summary: 'Modern SHA-2 digest with a 384-bit output.',
    ),
    const HashAlgorithmDescriptor(
      id: 'sha512',
      displayName: 'SHA-512',
      outputBits: 512,
      status: AlgorithmStatus.recommended,
      registryName: 'SHA-512',
      summary: 'Modern SHA-2 digest with a 512-bit output.',
    ),
    const HashAlgorithmDescriptor(
      id: 'sha512-224',
      displayName: 'SHA-512/224',
      outputBits: 224,
      status: AlgorithmStatus.acceptable,
      registryName: 'SHA-512/224',
      summary: 'SHA-512 family digest truncated according to FIPS 180-4.',
    ),
    const HashAlgorithmDescriptor(
      id: 'sha512-256',
      displayName: 'SHA-512/256',
      outputBits: 256,
      status: AlgorithmStatus.recommended,
      registryName: 'SHA-512/256',
      summary: 'SHA-512 family digest with a standardized 256-bit output.',
    ),
    const HashAlgorithmDescriptor(
      id: 'sha3-224',
      displayName: 'SHA3-224',
      outputBits: 224,
      status: AlgorithmStatus.acceptable,
      registryName: 'SHA3-224',
      summary: 'FIPS 202 SHA-3 digest with a 224-bit output.',
    ),
    const HashAlgorithmDescriptor(
      id: 'sha3-256',
      displayName: 'SHA3-256',
      outputBits: 256,
      status: AlgorithmStatus.recommended,
      registryName: 'SHA3-256',
      summary: 'FIPS 202 SHA-3 digest with a 256-bit output.',
    ),
    const HashAlgorithmDescriptor(
      id: 'sha3-384',
      displayName: 'SHA3-384',
      outputBits: 384,
      status: AlgorithmStatus.recommended,
      registryName: 'SHA3-384',
      summary: 'FIPS 202 SHA-3 digest with a 384-bit output.',
    ),
    const HashAlgorithmDescriptor(
      id: 'sha3-512',
      displayName: 'SHA3-512',
      outputBits: 512,
      status: AlgorithmStatus.recommended,
      registryName: 'SHA3-512',
      summary: 'FIPS 202 SHA-3 digest with a 512-bit output.',
    ),
    const HashAlgorithmDescriptor(
      id: 'blake2b-256',
      displayName: 'BLAKE2b-256',
      outputBits: 256,
      status: AlgorithmStatus.recommended,
      summary: 'Modern high-performance BLAKE2b digest with 256-bit output.',
    ),
    const HashAlgorithmDescriptor(
      id: 'blake2b-512',
      displayName: 'BLAKE2b-512',
      outputBits: 512,
      status: AlgorithmStatus.recommended,
      summary: 'Modern high-performance BLAKE2b digest with 512-bit output.',
    ),
    const HashAlgorithmDescriptor(
      id: 'sha224',
      displayName: 'SHA-224',
      outputBits: 224,
      status: AlgorithmStatus.acceptable,
      registryName: 'SHA-224',
      summary: 'SHA-2 digest with a 224-bit output.',
    ),
    const HashAlgorithmDescriptor(
      id: 'sm3',
      displayName: 'SM3',
      outputBits: 256,
      status: AlgorithmStatus.acceptable,
      registryName: 'SM3',
      summary: '256-bit cryptographic digest standardized in China.',
    ),
    const HashAlgorithmDescriptor(
      id: 'whirlpool',
      displayName: 'Whirlpool',
      outputBits: 512,
      status: AlgorithmStatus.acceptable,
      registryName: 'Whirlpool',
      summary: '512-bit cryptographic digest retained for interoperability.',
    ),
    const HashAlgorithmDescriptor(
      id: 'ripemd256',
      displayName: 'RIPEMD-256',
      outputBits: 256,
      status: AlgorithmStatus.acceptable,
      registryName: 'RIPEMD-256',
      summary: 'RIPEMD family digest retained for interoperability.',
    ),
    const HashAlgorithmDescriptor(
      id: 'ripemd320',
      displayName: 'RIPEMD-320',
      outputBits: 320,
      status: AlgorithmStatus.acceptable,
      registryName: 'RIPEMD-320',
      summary: 'RIPEMD family digest retained for interoperability.',
    ),
    const HashAlgorithmDescriptor(
      id: 'sha1',
      displayName: 'SHA-1',
      outputBits: 160,
      status: AlgorithmStatus.legacy,
      registryName: 'SHA-1',
      summary: 'Legacy digest available only for compatibility.',
      warning:
          'Collision attacks are practical. Do not use SHA-1 as the only integrity algorithm.',
    ),
    const HashAlgorithmDescriptor(
      id: 'ripemd160',
      displayName: 'RIPEMD-160',
      outputBits: 160,
      status: AlgorithmStatus.legacy,
      registryName: 'RIPEMD-160',
      summary: 'Legacy 160-bit digest retained for compatibility.',
      warning: 'Use a modern 256-bit or stronger algorithm for new manifests.',
    ),
    const HashAlgorithmDescriptor(
      id: 'tiger',
      displayName: 'Tiger',
      outputBits: 192,
      status: AlgorithmStatus.legacy,
      registryName: 'Tiger',
      summary:
          'Legacy digest retained for compatibility with existing systems.',
      warning: 'Not recommended for new integrity baselines.',
    ),
    const HashAlgorithmDescriptor(
      id: 'md5',
      displayName: 'MD5',
      outputBits: 128,
      status: AlgorithmStatus.obsolete,
      registryName: 'MD5',
      summary:
          'Obsolete digest available for compatibility with legacy procedures.',
      warning:
          'MD5 is collision-broken. Pair it with a modern algorithm and never treat it as proof of authenticity.',
    ),
    const HashAlgorithmDescriptor(
      id: 'md4',
      displayName: 'MD4',
      outputBits: 128,
      status: AlgorithmStatus.obsolete,
      registryName: 'MD4',
      summary: 'Obsolete digest retained only for historical compatibility.',
      warning:
          'MD4 is cryptographically broken and must not be used for security decisions.',
    ),
    const HashAlgorithmDescriptor(
      id: 'md2',
      displayName: 'MD2',
      outputBits: 128,
      status: AlgorithmStatus.obsolete,
      registryName: 'MD2',
      summary: 'Obsolete digest retained only for historical compatibility.',
      warning:
          'MD2 is cryptographically broken and must not be used for security decisions.',
    ),
    const HashAlgorithmDescriptor(
      id: 'crc32',
      displayName: 'CRC-32',
      outputBits: 32,
      status: AlgorithmStatus.checksum,
      summary: 'Fast accidental-corruption checksum; not a cryptographic hash.',
      warning: 'CRC-32 does not protect against deliberate modification.',
    ),
    const HashAlgorithmDescriptor(
      id: 'adler32',
      displayName: 'Adler-32',
      outputBits: 32,
      status: AlgorithmStatus.checksum,
      summary: 'Fast accidental-corruption checksum; not a cryptographic hash.',
      warning: 'Adler-32 does not protect against deliberate modification.',
    ),
  ];

  List<HashAlgorithmDescriptor> get all => <HashAlgorithmDescriptor>[
        ...builtIns,
        ..._customAlgorithms.values.map((algorithm) => algorithm.descriptor),
      ];

  HashAlgorithmDescriptor descriptor(String id) {
    for (final descriptor in builtIns) {
      if (descriptor.id == id) {
        return descriptor;
      }
    }
    final custom = _customAlgorithms[id];
    if (custom != null) {
      return custom.descriptor;
    }
    throw ArgumentError.value(id, 'id', 'Unknown hash algorithm.');
  }

  CustomHashAlgorithm? custom(String id) => _customAlgorithms[id];

  Digest createDigest(String id) {
    if (id == 'blake2b-256') {
      return Blake2bDigest(digestSize: 32);
    }
    if (id == 'blake2b-512') {
      return Blake2bDigest(digestSize: 64);
    }
    final algorithmDescriptor = descriptor(id);
    final registryName = algorithmDescriptor.registryName;
    if (registryName == null) {
      throw StateError('$id is not backed by a PointyCastle digest.');
    }
    return Digest(registryName);
  }

  String digestBytes(String id, Uint8List bytes) {
    final digest = createDigest(id);
    digest.update(bytes, 0, bytes.length);
    final output = Uint8List(digest.digestSize);
    digest.doFinal(output, 0);
    return hexEncode(output);
  }
}
