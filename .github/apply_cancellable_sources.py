from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Pattern not found: {label}')
    return text.replace(old, new, 1)


path = Path('lib/src/core/source.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    "import 'profile.dart';\n",
    "import 'profile.dart';\nimport 'scan_control.dart';\n",
    'source scan control import',
)
insert = '''
abstract interface class CancellableCommandRunner {
  Future<ProcessResultData> runCancellable(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    required ScanCancellationToken cancellationToken,
  });
}

'''
text = replace_once(
    text,
    'class SystemCommandRunner implements CommandRunner {\n',
    insert + 'class SystemCommandRunner implements CommandRunner, CancellableCommandRunner {\n',
    'cancellable command interface',
)
anchor = '''  @override
  Future<ProcessResultData> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    final future = Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: false,
      stdoutEncoding: null,
      stderrEncoding: null,
    );
    final result =
        timeout == null ? await future : await future.timeout(timeout);
    return ProcessResultData(
      exitCode: result.exitCode,
      stdoutBytes:
          Uint8List.fromList((result.stdout as List<int>?) ?? const <int>[]),
      stderrBytes:
          Uint8List.fromList((result.stderr as List<int>?) ?? const <int>[]),
    );
  }
'''
replacement = anchor + '''

  @override
  Future<ProcessResultData> runCancellable(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    required ScanCancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: false,
    );
    final stdoutFuture = process.stdout.fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    final stderrFuture = process.stderr.fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    final removeCancellation = cancellationToken.addListener(() {
      process.kill(Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigkill);
    });
    try {
      final exitFuture = process.exitCode;
      final exitCode = timeout == null
          ? await cancellationToken.race(exitFuture)
          : await cancellationToken.race(exitFuture.timeout(timeout));
      cancellationToken.throwIfCancelled();
      return ProcessResultData(
        exitCode: exitCode,
        stdoutBytes: Uint8List.fromList(await stdoutFuture),
        stderrBytes: Uint8List.fromList(await stderrFuture),
      );
    } on TimeoutException {
      process.kill(Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigkill);
      rethrow;
    } finally {
      removeCancellation();
    }
  }
'''
text = replace_once(text, anchor, replacement, 'cancellable system command')
text = replace_once(
    text,
    '''    SshSnapshotProgressCallback? onSshProgress,
  });
''',
    '''    SshSnapshotProgressCallback? onSshProgress,
    ScanCancellationToken? cancellationToken,
  });
''',
    'source provider contract token',
)
text = text.replace(
    '''    SshSnapshotProgressCallback? onSshProgress,
  }) async {
''',
    '''    SshSnapshotProgressCallback? onSshProgress,
    ScanCancellationToken? cancellationToken,
  }) async {
''',
)
text = replace_once(
    text,
    '''    final directory = Directory(config.root).absolute;
''',
    '''    cancellationToken?.throwIfCancelled();
    final directory = Directory(config.root).absolute;
''',
    'local source cancellation',
)
text = replace_once(
    text,
    '''      secrets: sshSecrets ?? const SshConnectionSecrets(),
    );
''',
    '''      secrets: sshSecrets ?? const SshConnectionSecrets(),
      cancellationToken: cancellationToken,
    );
''',
    'legacy SSH provider cancellation',
)
text = replace_once(
    text,
    '''        onProgress: onSshProgress,
      );
''',
    '''        onProgress: onSshProgress,
        cancellationToken: cancellationToken,
      );
''',
    'legacy snapshot cancellation',
)
text = text.replace(
    '''      final result = await runner.run(
        command.$1,
        command.$2,
        timeout: const Duration(minutes: 30),
      );
''',
    '''      final result = await runSourceCommand(
        runner,
        command.$1,
        command.$2,
        timeout: const Duration(minutes: 30),
        cancellationToken: cancellationToken,
      );
''',
)
text = text.replace(
    '''    final create = await runner.run('docker', createArguments,
        timeout: const Duration(minutes: 10));
''',
    '''    final create = await runSourceCommand(
      runner,
      'docker',
      createArguments,
      timeout: const Duration(minutes: 10),
      cancellationToken: cancellationToken,
    );
''',
)
text = text.replace(
    '''      await runner.run(
        'docker',
        <String>[...dockerContextArguments(config), 'rm', '-f', containerId],
      );
''',
    '''      await runSourceCommand(
        runner,
        'docker',
        <String>[...dockerContextArguments(config), 'rm', '-f', containerId],
        cancellationToken: null,
      );
''',
)
text = text.replace(
    '''      final copy = await runner.run('docker', copyArguments,
          timeout: const Duration(minutes: 30));
''',
    '''      final copy = await runSourceCommand(
        runner,
        'docker',
        copyArguments,
        timeout: const Duration(minutes: 30),
        cancellationToken: cancellationToken,
      );
''',
)
helper_anchor = '''List<String> dockerContextArguments(SourceConfig config) =>
'''
helper = '''Future<ProcessResultData> runSourceCommand(
  CommandRunner runner,
  String executable,
  List<String> arguments, {
  Duration? timeout,
  ScanCancellationToken? cancellationToken,
}) {
  if (cancellationToken != null && runner is CancellableCommandRunner) {
    return runner.runCancellable(
      executable,
      arguments,
      timeout: timeout,
      cancellationToken: cancellationToken,
    );
  }
  final operation = runner.run(executable, arguments, timeout: timeout);
  return cancellationToken == null ? operation : cancellationToken.race(operation);
}

'''
text = replace_once(text, helper_anchor, helper + helper_anchor, 'source command helper')
path.write_text(text, encoding='utf-8')
