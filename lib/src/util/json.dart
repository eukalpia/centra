import 'dart:convert';

Object? normalizeJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: normalizeJson(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(normalizeJson).toList(growable: false);
  }
  return value;
}

String canonicalJson(Object? value) => jsonEncode(normalizeJson(value));

String prettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(normalizeJson(value));

Map<String, Object?> decodeJsonObject(String source) {
  final value = jsonDecode(source);
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected a JSON object.');
  }
  return value;
}
