import 'dart:convert';
import 'dart:typed_data';

import 'package:centra/centra.dart';
import 'package:test/test.dart';

void main() {
  group('AlgorithmRegistry', () {
    final registry = AlgorithmRegistry();
    final abc = Uint8List.fromList(utf8.encode('abc'));

    test('matches standard digest vectors', () {
      final vectors = <String, String>{
        'md5': '900150983cd24fb0d6963f7d28e17f72',
        'sha1': 'a9993e364706816aba3e25717850c26c9cd0d89d',
        'sha256':
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        'sha512':
            'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a'
                '2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f',
        'sha3-256':
            '3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532',
        'blake2b-512':
            'ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d'
                '17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923',
      };
      for (final entry in vectors.entries) {
        expect(
          registry.digestBytes(entry.key, abc),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('marks MD5 obsolete everywhere in its descriptor', () {
      final md5 = registry.descriptor('md5');
      expect(md5.status, AlgorithmStatus.obsolete);
      expect(md5.warning, isNotNull);
      expect(md5.warning, contains('collision'));
      expect(md5.toJson()['status'], 'obsolete');
    });

    test('distinguishes cryptographic algorithms from checksums', () {
      expect(registry.descriptor('crc32').status, AlgorithmStatus.checksum);
      expect(registry.descriptor('adler32').status, AlgorithmStatus.checksum);
      expect(registry.descriptor('sha256').status, AlgorithmStatus.recommended);
    });

    test('rejects unknown identifiers', () {
      expect(() => registry.descriptor('not-real'), throwsArgumentError);
      expect(() => registry.createDigest('not-real'), throwsArgumentError);
    });

    test('registers an explicit custom implementation', () {
      const custom = CustomHashAlgorithm(
        id: 'company-hash',
        displayName: 'Company Hash',
        executable: '/opt/company/hash',
        arguments: <String>['--hex', '{file}'],
        outputPattern: r'^([0-9a-f]+)$',
        outputGroup: 1,
        outputBits: 256,
      );
      final customRegistry = AlgorithmRegistry(
        customAlgorithms: const <CustomHashAlgorithm>[custom],
      );
      expect(
        customRegistry.descriptor('company-hash').status,
        AlgorithmStatus.custom,
      );
      expect(customRegistry.custom('company-hash'), same(custom));
    });
  });
}
