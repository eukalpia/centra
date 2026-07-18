import 'dart:io';

import 'package:centra/centra.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late Directory output;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('centra-production-scan-');
    output = await Directory.systemTemp.createTemp('centra-production-output-');
    await File('${root.path}/a.txt').writeAsString('alpha');
    await Directory('${root.path}/node_modules/pkg').create(recursive: true);
    await File('${root.path}/node_modules/pkg/ignored.js')
        .writeAsString('ignored');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
    if (await output.exists()) await output.delete(recursive: true);
  });

  test('prepare reports an estimate and reuses the same inventory', () async {
    final scanner = IntegrityScanner();
    final profile = _profile(root.path, output.path);
    final phases = <String>[];
    final prepared = await scanner.prepare(
      profile,
      onProgress: (progress) => phases.add(progress.phase),
    );
    expect(prepared.estimate.files, 1);
    expect(prepared.estimate.skipped, 1);
    expect(prepared.estimate.exclusions.single.pattern, 'node_modules/**');

    final result = await prepared.run();
    expect(result.summary.filesHashed, 1);
    expect(result.summary.skipped, 1);
    expect(result.manifest.files.single.path, 'a.txt');
    expect(phases, containsAll(<String>['source-prepare', 'estimate', 'complete']));
  });

  test('fast verification reuses trusted baseline digests', () async {
    final scanner = IntegrityScanner();
    final profile = _profile(root.path, output.path);
    final baseline = await scanner.scan(profile);
    final fastProfile = _profile(
      root.path,
      output.path,
      verificationMode: VerificationMode.fast,
    );
    final fast = await scanner.scan(
      fastProfile,
      baseline: baseline.manifest,
      verificationMode: VerificationMode.fast,
    );
    expect(
      fast.manifest.files.single.digests,
      baseline.manifest.files.single.digests,
    );
    expect(fast.summary.transferredBytes, 0);
  });

  test('cancellation disposes a prepared scan and blocks execution', () async {
    final token = ScanCancellationToken();
    final scanner = IntegrityScanner();
    final prepared = await scanner.prepare(
      _profile(root.path, output.path),
      cancellationToken: token,
    );
    token.cancel();
    await expectLater(
      prepared.run(),
      throwsA(isA<ScanCancelledException>()),
    );
  });
}

CentraProfile _profile(
  String root,
  String output, {
  VerificationMode verificationMode = VerificationMode.full,
}) {
  final now = DateTime.utc(2026, 7, 18);
  return CentraProfile(
    id: 'production-test',
    name: 'Production test',
    locale: 'en',
    source: SourceConfig(type: SourceType.local, root: root),
    algorithmIds: const <String>['sha256', 'md5'],
    includePatterns: const <String>['**'],
    excludePatterns: const <String>['node_modules/**'],
    customAlgorithms: const <CustomHashAlgorithm>[],
    symlinkPolicy: SymlinkPolicy.skip,
    includeHiddenFiles: true,
    capturePermissions: true,
    captureModificationTimes: true,
    workerCount: 2,
    failOnReadError: true,
    output: OutputConfig(
      directory: output,
      writeCanonicalJson: true,
      writeCompatibilityText: false,
      createZip: false,
      requireZipPassword: false,
      includeMetadataReport: true,
    ),
    projectKind: 'generic',
    createdAt: now,
    updatedAt: now,
    verificationMode: verificationMode,
    readErrorPolicy: ReadErrorPolicy.stop,
    limits: const ScanLimits(),
  );
}
