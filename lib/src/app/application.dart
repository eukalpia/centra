import 'dart:io';

import 'cli.dart';
import '../tui/centra_app.dart';

class CentraApplication {
  CentraApplication({CentraCli? cli}) : cli = cli ?? CentraCli();

  final CentraCli cli;

  Future<int> run(List<String> arguments) async {
    if (arguments.isEmpty ||
        arguments.first == 'init' ||
        arguments.first == 'tui') {
      if (!stdin.hasTerminal || !stdout.hasTerminal) {
        stderr.writeln(
            'The interactive interface requires a terminal. Use `centra --help` for CLI commands.');
        return ExitCode.usage;
      }
      await runCentraTui(
          paths: cli.paths,
          forceWizard: arguments.isNotEmpty && arguments.first == 'init');
      return ExitCode.success;
    }
    return cli.run(arguments);
  }
}
