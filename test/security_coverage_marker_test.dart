import 'package:centra/centra.dart';
import 'package:test/test.dart';

void main() {
  test('public API exposes hardened storage and output services', () {
    expect(CentraSettings.defaults.locale, 'en');
    expect(const ManifestCodec(), isA<ManifestCodec>());
    expect(OutputService(), isA<OutputService>());
    expect(SignatureService(), isA<SignatureService>());
  });
}
