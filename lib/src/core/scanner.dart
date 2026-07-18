import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../util/hex.dart';
import 'algorithm_registry.dart';
import 'local_scan_engine.dart';
import 'manifest.dart';
import 'path_policy.dart';
import 'profile.dart';
import 'scan_control.dart';
import 'scan_result.dart';
import 'source.dart';
import 'ssh_connection.dart';
import 'ssh_scan_engine.dart';

export 'scan_control.dart';
export 'scan_result.dart';

const centraVersion = '0.2.0';

class IntegrityScanner {
  IntegrityScanner({
    SourceRegistry? sourceRegistry,
    SshConnectionService sshService = const SshConnectionService(),
    CommandRunner commandRunner = const SystemCommandRunner(),
    DateTime Function()? clock,
    Random? random,
    LocalScanEngine localEngine = const LocalScanEngine(),
    SshScanEngine sshEngine = const SshScanEngine(),
  })  : _sourceRegistry =
            sourceRegistry ?? SourceRegistry(runner: commandRunner),
        _sshService = sshService,
        _commandRunner = commandRunner,
        _clock = clock ?? DateTime.now,
        _random = random ?? Random.secure(),
        _localEngine = localEngine,
        _sshEngine = sshEngine;

  final SourceRegistry _sourceRegistry;
  final SshConnectionService _sshService;
  final CommandRunner _commandRunner;
  final DateTime Function() _clock;
  final Random _random;
  final LocalScanEngine _localEngine;
  final SshScanEngine _sshEngine;

  Future<PreparedScan> prepare(
    CentraProfile profile, {
    ScanProgressCallback? onProgress,
    SshConnectionSecrets? sshSecrets,
    ScanCancellationToken? cancellationToken,
  }) async {
    final validationErrors = profile.validate();
    if (validationErrors.isNotEmpty) {
      throw FormatException(validationErrors.join('\n'));
    }
    final token = cancellationToken ?? ScanCancellationToken();
    final policy = PathPolicy(
      includes: profile.includePatterns,
      excludes: profile.excludePatterns,
      includeHiddenFiles: profile.includeHiddenFiles,
    );
    final prepareWatch = Stopwatch()..start();
    onProgress?.call(ScanProgress(
      phase: profile.source.type == SourceType.ssh
          ? 'ssh-connect'
          : 'source-prepare',
      discovered: 0,
      completed: 0,
      totalBytes: 0,
      currentPath: profile.source.root,
      elapsed: prepareWatch.elapsed,
    ));

    if (profile.source.type == SourceType.ssh) {
      return _prepareSsh(
        profile,
        policy,
        token,
        sshSecrets ?? const SshConnectionSecrets(),
        onProgress,
        prepareWatch,
      );
    }
    return _prepareDirectorySource(
      profile,
      policy,
      token,
      sshSecrets,
      onProgress,
      prepareWatch,
    );
  }

  Future<PreparedScan> _prepareSsh(
    CentraProfile profile,
    PathPolicy policy,
    ScanCancellationToken token,
    SshConnectionSecrets secrets,
    ScanProgressCallback? onProgress,
    Stopwatch prepareWatch,
  ) async {
    final connection = await _sshService.connect(
      profile.source,
      secrets: secrets,
      cancellationToken: token,
    );
    var disposed = false;
    final removeCancellation = token.addListener(() {
      unawaited(connection.close());
    });
    try {
      final inventory = await connection.inventoryRemote(
        profile.source.root,
        pathPolicy: policy,
        limits: profile.limits,
        symlinkPolicy: profile.symlinkPolicy,
        readErrorPolicy: profile.effectiveReadErrorPolicy,
        readRetryCount: profile.readRetryCount,
        cancellationToken: token,
        onProgress: onProgress,
      );
      final durations = _estimatedDurations(inventory.totalBytes, remote: true);
      final estimate = inventory.toEstimate(
        minimumDuration: durations.$1,
        maximumDuration: durations.$2,
      );
      onProgress?.call(ScanProgress(
        phase: 'estimate',
        discovered: inventory.entries.length,
        completed: 0,
        totalBytes: 0,
        currentPath: profile.source.root,
        directories: inventory.directories,
        skipped: inventory.skipped,
        readErrors: inventory.issues.length,
        expectedBytes: inventory.totalBytes,
        elapsed: prepareWatch.elapsed,
      ));
      return PreparedScan(
        estimate: estimate,
        execute: ({baseline, verificationMode, baselineMetadata}) =>
            _executeSsh(
          profile: profile,
          connection: connection,
          inventory: inventory,
          estimate: estimate,
          token: token,
          onProgress: onProgress,
          baseline: baseline,
          verificationMode: verificationMode ?? profile.verificationMode,
          baselineMetadata: baselineMetadata,
        ),
        dispose: () async {
          if (disposed) return;
          disposed = true;
          removeCancellation();
          await connection.close();
        },
      );
    } on Object {
      removeCancellation();
      await connection.close();
      rethrow;
    }
  }

  Future<PreparedScan> _prepareDirectorySource(
    CentraProfile profile,
    PathPolicy policy,
    ScanCancellationToken token,
    SshConnectionSecrets? sshSecrets,
    ScanProgressCallback? onProgress,
    Stopwatch prepareWatch,
  ) async {
    final prepared = await token.race(
      _sourceRegistry.provider(profile.source.type).prepare(
            profile.source,
            sshSecrets: sshSecrets,
            pathPolicy: policy,
            workerCount: profile.workerCount,
            cancellationToken: token,
          ),
    );
    var disposed = false;
    final removeCancellation = token.addListener(() {
      unawaited(prepared.dispose());
    });
    try {
      final plan = await _localEngine.inventory(
        prepared.directory,
        profile: profile,
        pathPolicy: policy,
        cancellationToken: token,
        onProgress: onProgress,
      );
      final durations = _estimatedDurations(plan.totalBytes, remote: false);
      final estimate = plan.estimate(
        minimumDuration: durations.$1,
        maximumDuration: durations.$2,
      );
      onProgress?.call(ScanProgress(
        phase: 'estimate',
        discovered: plan.entries.length,
        completed: 0,
        totalBytes: 0,
        currentPath: prepared.directory.path,
        directories: plan.directories,
        skipped: plan.skipped,
        readErrors: plan.issues.length,
        expectedBytes: plan.totalBytes,
        elapsed: prepareWatch.elapsed,
      ));
      return PreparedScan(
        estimate: estimate,
        execute: ({baseline, verificationMode, baselineMetadata}) =>
            _executeLocal(
          profile: profile,
          prepared: prepared,
          plan: plan,
          estimate: estimate,
          token: token,
          onProgress: onProgress,
          baseline: baseline,
          verificationMode: verificationMode ?? profile.verificationMode,
          baselineMetadata: baselineMetadata,
        ),
        dispose: () async {
          if (disposed) return;
          disposed = true;
          removeCancellation();
          await prepared.dispose();
        },
      );
    } on Object {
      removeCancellation();
      await prepared.dispose();
      rethrow;
    }
  }

  Future<ScanResult> scan(
    CentraProfile profile, {
    ScanProgressCallback? onProgress,
    SshConnectionSecrets? sshSecrets,
    ScanCancellationToken? cancellationToken,
    CentraManifest? baseline,
    VerificationMode? verificationMode,
    Map<String, Object?>? baselineMetadata,
  }) async {
    final prepared = await prepare(
      profile,
      onProgress: onProgress,
      sshSecrets: sshSecrets,
      cancellationToken: cancellationToken,
    );
    return prepared.run(
      baseline: baseline,
      verificationMode: verificationMode,
      baselineMetadata: baselineMetadata,
    );
  }

  Future<ScanResult> _executeSsh({
    required CentraProfile profile,
    required SshConnection connection,
    required SshInventoryResult inventory,
    required ScanEstimate estimate,
    required ScanCancellationToken token,
    required ScanProgressCallback? onProgress,
    required VerificationMode verificationMode,
    CentraManifest? baseline,
    Map<String, Object?>? baselineMetadata,
  }) async {
    final stopwatch = Stopwatch()..start();
    final registry =
        AlgorithmRegistry(customAlgorithms: profile.customAlgorithms);
    final descriptors =
        profile.algorithmIds.map(registry.descriptor).toList(growable: false);
    final execution = await _sshEngine.execute(
      connection,
      inventory,
      profile: profile,
      registry: registry,
      runCustom: _runCustom,
      cancellationToken: token,
      verificationMode: verificationMode,
      baseline: baseline,
      onProgress: onProgress,
    );
    stopwatch.stop();
    return buildScanResult(
      toolVersion: centraVersion,
      manifestId: _manifestId(_clock().toUtc()),
      generatedAt: _clock().toUtc(),
      profile: profile,
      source: <String, Object?>{
        'type': SourceType.ssh.wireName,
        'root': inventory.root,
        'host': profile.source.host,
        'user': profile.source.user,
        'port': profile.source.port,
        'authMethod': profile.source.sshAuthMethod.wireName,
        if (profile.source.sshConnectionId != null)
          'connectionId': profile.source.sshConnectionId,
        if (profile.source.sshConnectionName != null)
          'connectionName': profile.source.sshConnectionName,
        'hostKeyType': connection.hostKeyType,
        'hostKeyFingerprint': connection.hostKeyFingerprint,
        'serverVersion': connection.serverVersion,
        'streamed': true,
      },
      descriptors: descriptors,
      records: execution.records,
      issues: execution.issues,
      directories: inventory.directories,
      skipped: inventory.skipped,
      unstableFiles: execution.unstableFiles,
      transferredBytes: execution.transferredBytes,
      duration: stopwatch.elapsed,
      estimate: estimate,
      baselineMetadata: baselineMetadata,
      onProgress: onProgress,
    );
  }

  Future<ScanResult> _executeLocal({
    required CentraProfile profile,
    required PreparedSource prepared,
    required LocalScanPlan plan,
    required ScanEstimate estimate,
    required ScanCancellationToken token,
    required ScanProgressCallback? onProgress,
    required VerificationMode verificationMode,
    CentraManifest? baseline,
    Map<String, Object?>? baselineMetadata,
  }) async {
    final stopwatch = Stopwatch()..start();
    final registry =
        AlgorithmRegistry(customAlgorithms: profile.customAlgorithms);
    final descriptors =
        profile.algorithmIds.map(registry.descriptor).toList(growable: false);
    final execution = await _localEngine.execute(
      plan,
      profile: profile,
      registry: registry,
      runCustom: _runCustom,
      cancellationToken: token,
      verificationMode: verificationMode,
      baseline: baseline,
      onProgress: onProgress,
    );
    stopwatch.stop();
    final generatedAt = _clock().toUtc();
    return buildScanResult(
      toolVersion: centraVersion,
      manifestId: _manifestId(generatedAt),
      generatedAt: generatedAt,
      profile: profile,
      source: prepared.metadata,
      descriptors: descriptors,
      records: execution.records,
      issues: execution.issues,
      directories: plan.directories,
      skipped: plan.skipped,
      unstableFiles: execution.unstableFiles,
      transferredBytes: execution.transferredBytes,
      duration: stopwatch.elapsed,
      estimate: estimate,
      baselineMetadata: baselineMetadata,
      onProgress: onProgress,
    );
  }

  Future<String> _runCustom(
    CustomHashAlgorithm algorithm,
    String filePath,
    ScanCancellationToken token,
  ) async {
    token.throwIfCancelled();
    final arguments = algorithm.arguments
        .map((argument) => argument.replaceAll('{file}', filePath))
        .toList(growable: false);
    final result = await token.race(
      _commandRunner.run(
        algorithm.executable,
        arguments,
        timeout: Duration(seconds: algorithm.timeoutSeconds),
      ),
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        algorithm.executable,
        arguments,
        result.stderrText,
        result.exitCode,
      );
    }
    final match = RegExp(
      algorithm.outputPattern,
      multiLine: true,
    ).firstMatch(result.stdoutText);
    if (match == null || algorithm.outputGroup > match.groupCount) {
      throw FormatException(
        'Custom algorithm ${algorithm.id} output did not match its configured pattern.',
      );
    }
    final value = match.group(algorithm.outputGroup)!.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(value)) {
      throw FormatException(
        'Custom algorithm ${algorithm.id} returned non-hexadecimal output.',
      );
    }
    if (algorithm.outputBits > 0 && value.length * 4 != algorithm.outputBits) {
      throw FormatException(
        'Custom algorithm ${algorithm.id} returned ${value.length * 4} bits; expected ${algorithm.outputBits}.',
      );
    }
    return value;
  }

  (Duration, Duration) _estimatedDurations(int bytes, {required bool remote}) {
    if (bytes <= 0) return (Duration.zero, Duration.zero);
    final fastBytesPerSecond = remote ? 50 * 1024 * 1024 : 350 * 1024 * 1024;
    final slowBytesPerSecond = remote ? 4 * 1024 * 1024 : 60 * 1024 * 1024;
    Duration estimate(int throughput) => Duration(
          milliseconds: max(1000, (bytes / throughput * 1000).round()),
        );
    return (estimate(fastBytesPerSecond), estimate(slowBytesPerSecond));
  }

  String _manifestId(DateTime generatedAt) {
    final randomPart = List<int>.generate(8, (_) => _random.nextInt(256));
    final timestamp = generatedAt
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 14);
    return '$timestamp-${hexEncode(randomPart)}';
  }
}
