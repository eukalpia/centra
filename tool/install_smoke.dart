import 'dart:io';

Future<void> main() async {
  final executable = Platform.isWindows
      ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache\\bin\\centra.bat'
      : '${Platform.environment['HOME']}/.pub-cache/bin/centra';

  final result = await Process.run(
    executable,
    const <String>['--version'],
    runInShell: Platform.isWindows,
  );

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    exitCode = result.exitCode;
    return;
  }

  final version = result.stdout.toString().trim();
  if (!RegExp(r'^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$').hasMatch(version)) {
    stderr.writeln('Unexpected Centra version: $version');
    exitCode = 1;
  }
}
