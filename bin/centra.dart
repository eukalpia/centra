import 'dart:io';

import 'package:centra/src/app/application.dart';

Future<void> main(List<String> arguments) async {
  final code = await CentraApplication().run(arguments);
  exitCode = code;
}
