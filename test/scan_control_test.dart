import 'dart:async';

import 'package:centra/centra.dart';
import 'package:test/test.dart';

void main() {
  group('ScanCancellationToken', () {
    test('interrupts an active raced operation', () async {
      final token = ScanCancellationToken();
      final operation = token.race(
        Future<String>.delayed(const Duration(seconds: 5), () => 'done'),
      );
      token.cancel();
      await expectLater(operation, throwsA(isA<ScanCancelledException>()));
      expect(token.isCancelled, isTrue);
    });

    test('runs cleanup listeners once', () {
      final token = ScanCancellationToken();
      var calls = 0;
      token.addListener(() => calls++);
      token.cancel();
      token.cancel();
      expect(calls, 1);
    });
  });

  test('progress exposes speed and ETA only after useful samples', () {
    const early = ScanProgress(
      phase: 'ssh-download',
      discovered: 10,
      completed: 1,
      totalBytes: 100,
      transferredBytes: 100,
      expectedBytes: 1000,
      elapsed: Duration(milliseconds: 500),
    );
    expect(early.bytesPerSecond, isNull);
    expect(early.eta, isNull);

    const stable = ScanProgress(
      phase: 'ssh-download',
      discovered: 10,
      completed: 5,
      totalBytes: 500,
      transferredBytes: 500,
      expectedBytes: 1000,
      elapsed: Duration(seconds: 5),
    );
    expect(stable.bytesPerSecond, 100);
    expect(stable.eta, const Duration(seconds: 5));
  });

  test('scan limits reject unsafe values', () {
    const limits = ScanLimits(
      fileTimeoutSeconds: 0,
      maximumFileBytes: -1,
      maximumFiles: 0,
      maximumDepth: 0,
    );
    expect(limits.validate(), hasLength(4));
  });
}
