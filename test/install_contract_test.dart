import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('pubspec exposes the centra global executable', () async {
    final pubspec = loadYaml(await File('pubspec.yaml').readAsString()) as YamlMap;
    final executables = pubspec['executables'] as YamlMap;

    expect(pubspec['name'], 'centra');
    expect(executables.containsKey('centra'), isTrue);
    expect(await File('bin/centra.dart').exists(), isTrue);
  });
}
