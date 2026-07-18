import 'dart:convert';

import 'package:centra/centra.dart';
import 'package:test/test.dart';

void main() {
  test('streaming pipeline hashes one byte stream with multiple algorithms', () {
    final pipeline = StreamingHashPipeline(
      registry: AlgorithmRegistry(),
      algorithmIds: const <String>['sha256', 'md5', 'crc32', 'adler32'],
    )
      ..add(utf8.encode('a'))
      ..add(utf8.encode('bc'));

    final values = pipeline.finish();
    expect(
      values['sha256'],
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(values['md5'], '900150983cd24fb0d6963f7d28e17f72');
    expect(values['crc32'], '352441c2');
    expect(values['adler32'], '024d0127');
    expect(pipeline.bytes, 3);
  });

  test('streaming pipeline cannot be reused after finish', () {
    final pipeline = StreamingHashPipeline(
      registry: AlgorithmRegistry(),
      algorithmIds: const <String>['sha256'],
    )..add(const <int>[1, 2, 3]);
    pipeline.finish();
    expect(() => pipeline.finish(), throwsStateError);
    expect(() => pipeline.add(const <int>[4]), throwsStateError);
  });
}
