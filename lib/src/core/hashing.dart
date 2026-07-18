import 'dart:async';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pointycastle/export.dart';

import '../util/hex.dart';
import 'algorithm_registry.dart';

abstract interface class HashAccumulator {
  void update(Uint8List bytes);
  String finish();
}

class DigestHashAccumulator implements HashAccumulator {
  DigestHashAccumulator(this.digest);

  final Digest digest;

  @override
  void update(Uint8List bytes) => digest.update(bytes, 0, bytes.length);

  @override
  String finish() {
    final output = Uint8List(digest.digestSize);
    digest.doFinal(output, 0);
    return hexEncode(output);
  }
}

class Crc32HashAccumulator implements HashAccumulator {
  var _value = 0;

  @override
  void update(Uint8List bytes) => _value = getCrc32(bytes, _value);

  @override
  String finish() => _value.toUnsigned(32).toRadixString(16).padLeft(8, '0');
}

class Adler32HashAccumulator implements HashAccumulator {
  var _value = 1;

  @override
  void update(Uint8List bytes) => _value = getAdler32(bytes, _value);

  @override
  String finish() => _value.toUnsigned(32).toRadixString(16).padLeft(8, '0');
}

class StreamingHashPipeline {
  StreamingHashPipeline({
    required AlgorithmRegistry registry,
    required Iterable<String> algorithmIds,
  }) : _accumulators = <String, HashAccumulator>{
          for (final id in algorithmIds)
            if (registry.custom(id) == null)
              id: switch (id) {
                'crc32' => Crc32HashAccumulator(),
                'adler32' => Adler32HashAccumulator(),
                _ => DigestHashAccumulator(registry.createDigest(id)),
              },
        };

  final Map<String, HashAccumulator> _accumulators;
  var _finished = false;
  var _bytes = 0;

  int get bytes => _bytes;

  void add(List<int> chunk) {
    if (_finished) throw StateError('Hash pipeline is already finished.');
    if (chunk.isEmpty) return;
    final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    _bytes += bytes.length;
    for (final accumulator in _accumulators.values) {
      accumulator.update(bytes);
    }
  }

  Map<String, String> finish() {
    if (_finished) throw StateError('Hash pipeline is already finished.');
    _finished = true;
    return <String, String>{
      for (final entry in _accumulators.entries)
        entry.key: entry.value.finish(),
    };
  }
}

class HashingStreamSink implements StreamSink<List<int>> {
  HashingStreamSink({
    required this.pipeline,
    this.mirror,
    this.onBytes,
  });

  final StreamingHashPipeline pipeline;
  final StreamSink<List<int>>? mirror;
  final void Function(int bytes)? onBytes;
  final Completer<void> _done = Completer<void>();
  var _closed = false;

  @override
  Future<void> get done => _done.future;

  @override
  void add(List<int> data) {
    if (_closed) throw StateError('Hashing sink is closed.');
    pipeline.add(data);
    mirror?.add(data);
    onBytes?.call(data.length);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (_closed) return;
    mirror?.addError(error, stackTrace);
    if (!_done.isCompleted) _done.completeError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await mirror?.close();
    if (!_done.isCompleted) _done.complete();
  }
}
