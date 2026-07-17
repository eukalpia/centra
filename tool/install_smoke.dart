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

  if (result.stdout.toString().trim() != '0.1.0') {
    stderr.writeln('Unexpected Centra version: ${result.stdout}');
    exitCode = 1;
  }
}
