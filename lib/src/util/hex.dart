import 'dart:typed_data';

const _hexAlphabet = '0123456789abcdef';

String hexEncode(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer
      ..write(_hexAlphabet[(byte >> 4) & 0x0f])
      ..write(_hexAlphabet[byte & 0x0f]);
  }
  return buffer.toString();
}

Uint8List hexDecode(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.length.isOdd || !RegExp(r'^[0-9a-f]*$').hasMatch(normalized)) {
    throw const FormatException('Expected an even-length hexadecimal string.');
  }
  final bytes = Uint8List(normalized.length ~/ 2);
  for (var index = 0; index < normalized.length; index += 2) {
    bytes[index ~/ 2] =
        int.parse(normalized.substring(index, index + 2), radix: 16);
  }
  return bytes;
}

bool constantTimeHexEquals(String left, String right) {
  final a = left.trim().toLowerCase().codeUnits;
  final b = right.trim().toLowerCase().codeUnits;
  var difference = a.length ^ b.length;
  final length = a.length > b.length ? a.length : b.length;
  for (var index = 0; index < length; index++) {
    final av = index < a.length ? a[index] : 0;
    final bv = index < b.length ? b[index] : 0;
    difference |= av ^ bv;
  }
  return difference == 0;
}
