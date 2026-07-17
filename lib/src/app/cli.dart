import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

import '../core/algorithm_registry.dart';
import '../core/manifest.dart';
import '../core/profile.dart';
import '../core/scanner.dart';
import '../core/services.dart';
import '../core/storage.dart';
import '../util/json.dart';

abstract final class ExitCode {
  static const success = 0;
  static const usage = 2;
  static const differences = 3;
  static const configuration = 4;
  static const source = 5;
  static const fileSystem = 6;
  static const signature = 7;
  static const internal = 70;
}

class CentraCli {
  CentraCli({
    CentraPaths? paths,
    IntegrityScanner? scanner,
    OutputService? outputService,
    SignatureService? signatureService,
    ManifestCodec manifestCodec = const ManifestCodec(),
  }) : paths = paths ?? CentraPaths(),
       scanner = scanner ?? IntegrityScanner(),
       outputService = outputService ?? OutputService(),
       signatureService = signatureService ?? SignatureService(),
       manifestCodec = manifestCodec;

  final CentraPaths paths;
  final IntegrityScanner scanner;
  final OutputService outputService;
  final SignatureService signatureService;
  final ManifestCodec manifestCodec;

  late final ProfileStore profiles = ProfileStore(paths);

  ArgParser buildParser() {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show command help.')
      ..addFlag('version', negatable: false, help: 'Show Centra version.');

    parser.addCommand(
      'algorithms',
      ArgParser()..addFlag(
        'json',
        negatable: false,
        help: 'Write machine-readable JSON.',
      ),
    );

    final profileParser = ArgParser();
    profileParser.addCommand(
      'list',
      ArgParser()..addFlag('json', negatable: false),
    );
    profileParser.addCommand(
      'show',
      ArgParser()
        ..addOption('id', abbr: 'p', help: 'Profile ID.', mandatory: true)
        ..addFlag('json', negatable: false),
    );
    profileParser.addCommand(
      'delete',
      ArgParser()
        ..addOption('id', abbr: 'p', help: 'Profile ID.', mandatory: true)
        ..addFlag(
          'yes',
          abbr: 'y',
          negatable: false,
          help: 'Confirm deletion.',
        ),
    );
    profileParser.addCommand(
      'import',
      ArgParser()..addOption(
        'file',
        abbr: 'f',
        help: 'Profile JSON file.',
        mandatory: true,
      ),
    );
    profileParser.addCommand(
      'export',
      ArgParser()
        ..addOption('id', abbr: 'p', help: 'Profile ID.', mandatory: true)
        ..addOption(
          'file',
          abbr: 'f',
          help: 'Destination JSON file.',
          mandatory: true,
        ),
    );
    parser.addCommand('profiles', profileParser);

    parser.addCommand(
      'scan',
      ArgParser()
        ..addOption('profile', abbr: 'p', help: 'Profile ID.', mandatory: true)
        ..addOption(
          'password-env',
          help: 'Environment variable containing the ZIP password.',
        )
        ..addFlag(
          'json',
          negatable: false,
          help: 'Write machine-readable JSON.',
        ),
    );

    parser.addCommand(
      'verify',
      ArgParser()
        ..addOption('profile', abbr: 'p', help: 'Profile ID.', mandatory: true)
        ..addOption(
          'manifest',
          abbr: 'm',
          help: 'Approved manifest file.',
          mandatory: true,
        )
        ..addFlag(
          'json',
          negatable: false,
          help: 'Write machine-readable JSON.',
        ),
    );

    parser.addCommand(
      'diff',
      ArgParser()
        ..addOption('before', help: 'Earlier manifest file.', mandatory: true)
        ..addOption('after', help: 'Later manifest file.', mandatory: true)
        ..addFlag(
          'json',
          negatable: false,
          help: 'Write machine-readable JSON.',
        )
        ..addFlag(
          'include-unchanged',
          negatable: false,
          help: 'Include unchanged files.',
        ),
    );

    parser.addCommand(
      'keygen',
      ArgParser()
        ..addOption('id', help: 'Signing key ID.', mandatory: true)
        ..addOption(
          'private',
          help: 'Private key output file.',
          mandatory: true,
        )
        ..addOption('public', help: 'Public key output file.', mandatory: true),
    );

    parser.addCommand(
      'sign',
      ArgParser()
        ..addOption(
          'manifest',
          abbr: 'm',
          help: 'Manifest file.',
          mandatory: true,
        )
        ..addOption(
          'key',
          abbr: 'k',
          help: 'Private key file.',
          mandatory: true,
        )
        ..addOption(
          'output',
          abbr: 'o',
          help: 'Signature document output.',
          mandatory: true,
        ),
    );

    parser.addCommand(
      'verify-signature',
      ArgParser()
        ..addOption(
          'manifest',
          abbr: 'm',
          help: 'Manifest file.',
          mandatory: true,
        )
        ..addOption(
          'signature',
          abbr: 's',
          help: 'Signature document.',
          mandatory: true,
        )
        ..addOption(
          'public-key',
          abbr: 'k',
          help: 'Optional trusted public key document.',
        )
        ..addFlag('json', negatable: false),
    );

    parser.addCommand('doctor', ArgParser()..addFlag('json', negatable: false));
    return parser;
  }

  Future<int> run(List<String> arguments) async {
    final parser = buildParser();
    late final ArgResults results;
    try {
      results = parser.parse(arguments);
    } on ArgParserException catch (error) {
      stderr.writeln(error.message);
      stderr.writeln('Run `centra --help` for usage.');
      return ExitCode.usage;
    }

    if (results['version'] as bool) {
      stdout.writeln(centraVersion);
      return ExitCode.success;
    }
    if (results['help'] as bool || results.command == null) {
      stdout.writeln(_help(parser));
      return ExitCode.success;
    }

    try {
      return switch (results.command!.name) {
        'algorithms' => _algorithms(results.command!),
        'profiles' => await _profiles(results.command!),
        'scan' => await _scan(results.command!),
        'verify' => await _verify(results.command!),
        'diff' => await _diff(results.command!),
        'keygen' => await _keygen(results.command!),
        'sign' => await _sign(results.command!),
        'verify-signature' => await _verifySignature(results.command!),
        'doctor' => await _doctor(results.command!),
        _ => ExitCode.usage,
      };
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      return ExitCode.configuration;
    } on ProcessException catch (error) {
      stderr.writeln(error);
      return ExitCode.source;
    } on FileSystemException catch (error) {
      stderr.writeln(error);
      return ExitCode.fileSystem;
    } on TimeoutException catch (error) {
      stderr.writeln(error);
      return ExitCode.source;
    } on Object catch (error, stackTrace) {
      stderr.writeln('Unexpected failure: $error');
      if (Platform.environment['CENTRA_DEBUG'] == '1')
        stderr.writeln(stackTrace);
      return ExitCode.internal;
    }
  }

  int _algorithms(ArgResults results) {
    final algorithms = AlgorithmRegistry.builtIns;
    if (results['json'] as bool) {
      stdout.writeln(
        prettyJson(<String, Object?>{
          'algorithms': algorithms
              .map((algorithm) => algorithm.toJson())
              .toList(),
        }),
      );
      return ExitCode.success;
    }
    stdout.writeln('ID                 BITS  STATUS       NAME');
    stdout.writeln('-----------------  ----  -----------  ----------------');
    for (final algorithm in algorithms) {
      stdout.writeln(
        '${algorithm.id.padRight(17)}  ${algorithm.outputBits.toString().padLeft(4)}  '
        '${algorithm.status.wireName.padRight(11)}  ${algorithm.displayName}',
      );
      if (algorithm.warning != null)
        stdout.writeln('  warning: ${algorithm.warning}');
    }
    return ExitCode.success;
  }

  Future<int> _profiles(ArgResults parent) async {
    final command = parent.command;
    if (command == null) {
      stderr.writeln('A profiles subcommand is required.');
      return ExitCode.usage;
    }
    switch (command.name) {
      case 'list':
        final list = await profiles.list();
        if (command['json'] as bool) {
          stdout.writeln(
            prettyJson(<String, Object?>{
              'profiles': list.map((profile) => profile.toJson()).toList(),
            }),
          );
        } else if (list.isEmpty) {
          stdout.writeln('No profiles configured. Run `centra init`.');
        } else {
          for (final profile in list) {
            stdout.writeln(
              '${profile.id.padRight(24)} ${profile.name}  [${profile.source.type.wireName}]',
            );
          }
        }
        return ExitCode.success;
      case 'show':
        final id = command['id']! as String;
        final profile = await profiles.load(id);
        if (profile == null) throw FormatException('Profile not found: $id');
        stdout.writeln(
          command['json'] as bool
              ? canonicalJson(profile.toJson())
              : prettyJson(profile.toJson()),
        );
        return ExitCode.success;
      case 'delete':
        if (!(command['yes'] as bool)) {
          stderr.writeln('Refusing to delete without --yes.');
          return ExitCode.usage;
        }
        final id = command['id']! as String;
        final deleted = await profiles.delete(id);
        stdout.writeln(
          deleted ? 'Deleted profile $id.' : 'Profile $id did not exist.',
        );
        return ExitCode.success;
      case 'import':
        final profile = await profiles.loadFile(
          File(command['file']! as String),
        );
        await profiles.save(profile);
        stdout.writeln('Imported profile ${profile.id}.');
        return ExitCode.success;
      case 'export':
        final id = command['id']! as String;
        final profile = await profiles.load(id);
        if (profile == null) throw FormatException('Profile not found: $id');
        await const AtomicFileWriter().writeText(
          File(command['file']! as String),
          '${prettyJson(profile.toJson())}\n',
        );
        stdout.writeln('Exported profile $id.');
        return ExitCode.success;
      default:
        return ExitCode.usage;
    }
  }

  Future<int> _scan(ArgResults results) async {
    final profile = await _requireProfile(results['profile']! as String);
    final password = _passwordFromEnvironment(
      results['password-env'] as String?,
    );
    final scan = await scanner.scan(
      profile,
      onProgress: (progress) {
        if (!(results['json'] as bool) && stderr.hasTerminal) {
          stderr.write(
            '\r${progress.phase.padRight(10)} ${progress.completed}/${progress.discovered} '
                    '${progress.currentPath ?? ''}'
                .padRight(120),
          );
        }
      },
    );
    if (!(results['json'] as bool) && stderr.hasTerminal) stderr.writeln();
    final artifacts = await outputService.write(
      profile,
      scan.manifest,
      zipPassword: password,
    );
    final result = <String, Object?>{
      'manifestId': scan.manifest.id,
      'durationMilliseconds': scan.duration.inMilliseconds,
      'files': scan.manifest.files.length,
      'bytes': scan.manifest.totalBytes,
      'readErrors': scan.manifest.errors.length,
      'artifacts': <Object?>[
        ...artifacts.artifacts.map(
          (artifact) => <String, Object?>{
            'kind': artifact.kind,
            'path': artifact.file.absolute.path,
            'bytes': artifact.bytes,
          },
        ),
        if (artifacts.archive != null)
          <String, Object?>{
            'kind': artifacts.archive!.kind,
            'path': artifacts.archive!.file.absolute.path,
            'bytes': artifacts.archive!.bytes,
          },
      ],
    };
    if (results['json'] as bool) {
      stdout.writeln(canonicalJson(result));
    } else {
      stdout.writeln('Manifest ${scan.manifest.id}');
      stdout.writeln(
        'Files: ${scan.manifest.files.length}  Bytes: ${scan.manifest.totalBytes}',
      );
      for (final artifact
          in (result['artifacts']! as List<Object?>)
              .cast<Map<String, Object?>>()) {
        stdout.writeln('${artifact['kind']}: ${artifact['path']}');
      }
    }
    return ExitCode.success;
  }

  Future<int> _verify(ArgResults results) async {
    final profile = await _requireProfile(results['profile']! as String);
    final approved = await manifestCodec.read(
      File(results['manifest']! as String),
    );
    final current = (await scanner.scan(profile)).manifest;
    final diff = const ManifestComparator().compare(approved, current);
    if (results['json'] as bool) {
      stdout.writeln(canonicalJson(diff.toJson()));
    } else {
      _writeDiff(diff);
    }
    return diff.hasIntegrityChanges ? ExitCode.differences : ExitCode.success;
  }

  Future<int> _diff(ArgResults results) async {
    final before = await manifestCodec.read(File(results['before']! as String));
    final after = await manifestCodec.read(File(results['after']! as String));
    var diff = const ManifestComparator().compare(before, after);
    if (!(results['include-unchanged'] as bool)) {
      diff = ManifestDiff(
        diff.changes
            .where((change) => change.type != ManifestChangeType.unchanged)
            .toList(),
      );
    }
    if (results['json'] as bool) {
      stdout.writeln(canonicalJson(diff.toJson()));
    } else {
      _writeDiff(diff);
    }
    return diff.hasIntegrityChanges ? ExitCode.differences : ExitCode.success;
  }

  Future<int> _keygen(ArgResults results) async {
    final key = await signatureService.generate(results['id']! as String);
    await signatureService.writeKeyPair(
      key,
      File(results['private']! as String),
      File(results['public']! as String),
    );
    stdout.writeln('Generated Ed25519 key ${key.id}.');
    return ExitCode.success;
  }

  Future<int> _sign(ArgResults results) async {
    final manifest = await manifestCodec.read(
      File(results['manifest']! as String),
    );
    final key = signatureService.decodePrivateKey(
      await File(results['key']! as String).readAsString(),
    );
    final document = await signatureService.sign(manifest, key);
    await const AtomicFileWriter().writeText(
      File(results['output']! as String),
      '${prettyJson(document.toJson())}\n',
    );
    stdout.writeln('Signed manifest ${manifest.id} with key ${key.id}.');
    return ExitCode.success;
  }

  Future<int> _verifySignature(ArgResults results) async {
    final manifest = await manifestCodec.read(
      File(results['manifest']! as String),
    );
    final document = ManifestSignatureDocument.fromJson(
      decodeJsonObject(
        await File(results['signature']! as String).readAsString(),
      ),
    );
    final publicKeyFile = results['public-key'] as String?;
    final publicKey = publicKeyFile == null
        ? null
        : signatureService.decodePublicKey(
            await File(publicKeyFile).readAsString(),
          );
    final valid = await signatureService.verify(
      manifest,
      document,
      publicKey: publicKey,
    );
    if (results['json'] as bool) {
      stdout.writeln(
        canonicalJson(<String, Object?>{
          'valid': valid,
          'manifestId': manifest.id,
          'keyId': document.keyId,
        }),
      );
    } else {
      stdout.writeln(
        valid
            ? 'VALID signature from ${document.keyId}.'
            : 'INVALID signature.',
      );
    }
    return valid ? ExitCode.success : ExitCode.signature;
  }

  Future<int> _doctor(ArgResults results) async {
    final checks = <String, Object?>{
      'dart': Platform.version.split(' ').first,
      'platform': Platform.operatingSystem,
      'configDirectory': paths.configDirectory.absolute.path,
      'dataDirectory': paths.dataDirectory.absolute.path,
      'ssh': await _executableAvailable('ssh'),
      'tar': await _executableAvailable('tar'),
      'docker': await _executableAvailable('docker'),
    };
    if (results['json'] as bool) {
      stdout.writeln(canonicalJson(checks));
    } else {
      checks.forEach(
        (key, value) => stdout.writeln('${key.padRight(18)} $value'),
      );
    }
    return ExitCode.success;
  }

  Future<CentraProfile> _requireProfile(String id) async {
    final profile = await profiles.load(id);
    if (profile == null) throw FormatException('Profile not found: $id');
    return profile;
  }

  String? _passwordFromEnvironment(String? variable) {
    if (variable == null) return null;
    final value = Platform.environment[variable];
    if (value == null || value.isEmpty) {
      throw FormatException(
        'Environment variable $variable is missing or empty.',
      );
    }
    return value;
  }

  Future<bool> _executableAvailable(String executable) async {
    try {
      final command = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(command, <String>[
        executable,
      ], runInShell: false);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  void _writeDiff(ManifestDiff diff) {
    stdout.writeln(
      'Added: ${diff.count(ManifestChangeType.added)}  '
      'Removed: ${diff.count(ManifestChangeType.removed)}  '
      'Modified: ${diff.count(ManifestChangeType.modified)}  '
      'Metadata: ${diff.count(ManifestChangeType.metadata)}',
    );
    for (final change in diff.changes) {
      if (change.type == ManifestChangeType.unchanged) continue;
      final algorithms = change.changedAlgorithms.isEmpty
          ? ''
          : ' [${change.changedAlgorithms.join(', ')}]';
      stdout.writeln(
        '${change.type.name.padRight(9)} ${change.path}$algorithms',
      );
    }
  }

  String _help(ArgParser parser) =>
      '''
Centra $centraVersion
File integrity, deployment verification, and manifest management.

Usage:
  centra                         Open the interactive interface
  centra init                    Open the first-run profile wizard
  centra <command> [options]

Commands:
  algorithms                     List supported algorithms and security status
  profiles list|show|delete      Manage saved profiles
  scan                           Create a manifest and selected output artifacts
  verify                         Scan a source and compare it with an approved manifest
  diff                           Compare two existing manifests
  keygen                         Generate an Ed25519 signing key pair
  sign                           Sign a canonical manifest
  verify-signature               Verify a detached manifest signature
  doctor                         Inspect local command availability

Global options:
${parser.usage}
''';
}
