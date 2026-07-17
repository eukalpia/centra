from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Pattern not found in {path}: {old[:120]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'pubspec.yaml',
    '  cryptography: ^2.9.0\n',
    '  cryptography: ^2.9.0\n  dartssh2: ^2.22.2\n',
)

replace_once(
    'lib/src/core/profile.dart',
    "extension SourceTypeName on SourceType {\n  String get wireName => switch (this) {\n        SourceType.local => 'local',\n        SourceType.ssh => 'ssh',\n        SourceType.dockerContainer => 'docker-container',\n        SourceType.dockerImage => 'docker-image',\n        SourceType.dockerCompose => 'docker-compose',\n      };\n\n  static SourceType parse(String value) => SourceType.values.firstWhere(\n        (type) => type.wireName == value,\n        orElse: () => throw FormatException('Unknown source type: $value'),\n      );\n}\n",
    "extension SourceTypeName on SourceType {\n  String get wireName => switch (this) {\n        SourceType.local => 'local',\n        SourceType.ssh => 'ssh',\n        SourceType.dockerContainer => 'docker-container',\n        SourceType.dockerImage => 'docker-image',\n        SourceType.dockerCompose => 'docker-compose',\n      };\n\n  static SourceType parse(String value) => SourceType.values.firstWhere(\n        (type) => type.wireName == value,\n        orElse: () => throw FormatException('Unknown source type: $value'),\n      );\n}\n\nenum SshAuthMethod {\n  password,\n  privateKey,\n  passwordAndKey,\n}\n\nextension SshAuthMethodName on SshAuthMethod {\n  String get wireName => switch (this) {\n        SshAuthMethod.password => 'password',\n        SshAuthMethod.privateKey => 'private-key',\n        SshAuthMethod.passwordAndKey => 'password-and-key',\n      };\n\n  bool get usesPassword =>\n      this == SshAuthMethod.password || this == SshAuthMethod.passwordAndKey;\n\n  bool get usesPrivateKey =>\n      this == SshAuthMethod.privateKey ||\n      this == SshAuthMethod.passwordAndKey;\n\n  static SshAuthMethod parse(String value) => SshAuthMethod.values.firstWhere(\n        (method) => method.wireName == value,\n        orElse: () => throw FormatException('Unknown SSH auth method: $value'),\n      );\n}\n\nenum SshHostKeyPolicy {\n  trustOnFirstUse,\n  pinned,\n}\n\nextension SshHostKeyPolicyName on SshHostKeyPolicy {\n  String get wireName => switch (this) {\n        SshHostKeyPolicy.trustOnFirstUse => 'trust-on-first-use',\n        SshHostKeyPolicy.pinned => 'pinned',\n      };\n\n  static SshHostKeyPolicy parse(String value) =>\n      SshHostKeyPolicy.values.firstWhere(\n        (policy) => policy.wireName == value,\n        orElse: () =>\n            throw FormatException('Unknown SSH host key policy: $value'),\n      );\n}\n",
)

replace_once(
    'lib/src/core/profile.dart',
    "    this.identityFile,\n    this.container,\n",
    "    this.identityFile,\n    this.sshAuthMethod = SshAuthMethod.privateKey,\n    this.sshHostKeyPolicy = SshHostKeyPolicy.trustOnFirstUse,\n    this.hostKeyType,\n    this.hostKeyFingerprint,\n    this.connectTimeoutSeconds = 15,\n    this.keepAliveSeconds = 10,\n    this.container,\n",
)
replace_once(
    'lib/src/core/profile.dart',
    "  final String? identityFile;\n  final String? container;\n",
    "  final String? identityFile;\n  final SshAuthMethod sshAuthMethod;\n  final SshHostKeyPolicy sshHostKeyPolicy;\n  final String? hostKeyType;\n  final String? hostKeyFingerprint;\n  final int connectTimeoutSeconds;\n  final int keepAliveSeconds;\n  final String? container;\n",
)
replace_once(
    'lib/src/core/profile.dart',
    "        if ((user ?? '').trim().isEmpty) errors.add('SSH user is required.');\n        if (port < 1 || port > 65535)\n          errors.add('SSH port must be between 1 and 65535.');\n        break;\n",
    "        if ((user ?? '').trim().isEmpty) errors.add('SSH user is required.');\n        if (port < 1 || port > 65535)\n          errors.add('SSH port must be between 1 and 65535.');\n        if (sshAuthMethod.usesPrivateKey &&\n            (identityFile ?? '').trim().isEmpty) {\n          errors.add('SSH private key file is required.');\n        }\n        if ((hostKeyFingerprint ?? '').trim().isEmpty) {\n          errors.add('SSH host key fingerprint is required.');\n        }\n        if (connectTimeoutSeconds < 1 || connectTimeoutSeconds > 300) {\n          errors.add('SSH timeout must be between 1 and 300 seconds.');\n        }\n        if (keepAliveSeconds < 0 || keepAliveSeconds > 3600) {\n          errors.add('SSH keepalive must be between 0 and 3600 seconds.');\n        }\n        break;\n",
)
replace_once(
    'lib/src/core/profile.dart',
    "        if (identityFile != null) 'identityFile': identityFile,\n        if (container != null) 'container': container,\n",
    "        if (identityFile != null) 'identityFile': identityFile,\n        if (type == SourceType.ssh) 'sshAuthMethod': sshAuthMethod.wireName,\n        if (type == SourceType.ssh)\n          'sshHostKeyPolicy': sshHostKeyPolicy.wireName,\n        if (hostKeyType != null) 'hostKeyType': hostKeyType,\n        if (hostKeyFingerprint != null)\n          'hostKeyFingerprint': hostKeyFingerprint,\n        if (type == SourceType.ssh)\n          'connectTimeoutSeconds': connectTimeoutSeconds,\n        if (type == SourceType.ssh) 'keepAliveSeconds': keepAliveSeconds,\n        if (container != null) 'container': container,\n",
)
replace_once(
    'lib/src/core/profile.dart',
    "        identityFile: json['identityFile'] as String?,\n        container: json['container'] as String?,\n",
    "        identityFile: json['identityFile'] as String?,\n        sshAuthMethod: SshAuthMethodName.parse(\n          json['sshAuthMethod'] as String? ?? 'private-key',\n        ),\n        sshHostKeyPolicy: SshHostKeyPolicyName.parse(\n          json['sshHostKeyPolicy'] as String? ?? 'trust-on-first-use',\n        ),\n        hostKeyType: json['hostKeyType'] as String?,\n        hostKeyFingerprint: json['hostKeyFingerprint'] as String?,\n        connectTimeoutSeconds: json['connectTimeoutSeconds'] as int? ?? 15,\n        keepAliveSeconds: json['keepAliveSeconds'] as int? ?? 10,\n        container: json['container'] as String?,\n",
)

replace_once(
    'lib/src/tui/wizard_state.dart',
    "  String identityFile = '';\n  String container = '';\n",
    "  String identityFile = '';\n  SshAuthMethod sshAuthMethod = SshAuthMethod.privateKey;\n  SshHostKeyPolicy sshHostKeyPolicy = SshHostKeyPolicy.trustOnFirstUse;\n  String hostKeyType = '';\n  String hostKeyFingerprint = '';\n  int connectTimeoutSeconds = 15;\n  int keepAliveSeconds = 10;\n  String container = '';\n",
)
replace_once(
    'lib/src/tui/wizard_state.dart',
    "        identityFile: identityFile.trim().isEmpty ? null : identityFile.trim(),\n        container: container.trim().isEmpty ? null : container.trim(),\n",
    "        identityFile: identityFile.trim().isEmpty ? null : identityFile.trim(),\n        sshAuthMethod: sshAuthMethod,\n        sshHostKeyPolicy: sshHostKeyPolicy,\n        hostKeyType: hostKeyType.trim().isEmpty ? null : hostKeyType.trim(),\n        hostKeyFingerprint: hostKeyFingerprint.trim().isEmpty\n            ? null\n            : hostKeyFingerprint.trim(),\n        connectTimeoutSeconds: connectTimeoutSeconds,\n        keepAliveSeconds: keepAliveSeconds,\n        container: container.trim().isEmpty ? null : container.trim(),\n",
)

replace_once(
    'lib/src/core/source.dart',
    "import 'profile.dart';\n",
    "import 'profile.dart';\nimport 'ssh_connection.dart';\n",
)
replace_once(
    'lib/src/core/source.dart',
    "  Future<PreparedSource> prepare(SourceConfig config);\n",
    "  Future<PreparedSource> prepare(\n    SourceConfig config, {\n    SshConnectionSecrets? sshSecrets,\n  });\n",
)
replace_once(
    'lib/src/core/source.dart',
    "  Future<PreparedSource> prepare(SourceConfig config) async {\n    final directory = Directory(config.root).absolute;\n",
    "  Future<PreparedSource> prepare(\n    SourceConfig config, {\n    SshConnectionSecrets? sshSecrets,\n  }) async {\n    final directory = Directory(config.root).absolute;\n",
)
replace_once(
    'lib/src/core/source.dart',
    "class ArchiveSourceProvider implements SourceProvider {\n",
    "class SshSourceProvider implements SourceProvider {\n  const SshSourceProvider({\n    this.service = const SshConnectionService(),\n  });\n\n  final SshConnectionService service;\n\n  @override\n  SourceType get type => SourceType.ssh;\n\n  @override\n  Future<PreparedSource> prepare(\n    SourceConfig config, {\n    SshConnectionSecrets? sshSecrets,\n  }) async {\n    final connection = await service.connect(\n      config,\n      secrets: sshSecrets ?? const SshConnectionSecrets(),\n    );\n    try {\n      final snapshot = await connection.downloadSnapshot(config.root);\n      return PreparedSource(\n        directory: snapshot.directory,\n        metadata: <String, Object?>{\n          'type': type.wireName,\n          'root': config.root,\n          'host': config.host,\n          'user': config.user,\n          'port': config.port,\n          'authMethod': config.sshAuthMethod.wireName,\n          'hostKeyType': connection.hostKeyType,\n          'hostKeyFingerprint': connection.hostKeyFingerprint,\n          'serverVersion': connection.serverVersion,\n          'snapshotFiles': snapshot.files,\n          'snapshotDirectories': snapshot.directories,\n          'snapshotSymlinks': snapshot.symlinks,\n        },\n        dispose: () async {\n          await connection.close();\n          if (await snapshot.directory.exists()) {\n            await snapshot.directory.delete(recursive: true);\n          }\n        },\n      );\n    } catch (_) {\n      await connection.close();\n      rethrow;\n    }\n  }\n}\n\nclass ArchiveSourceProvider implements SourceProvider {\n",
)
replace_once(
    'lib/src/core/source.dart',
    "  Future<PreparedSource> prepare(SourceConfig config) async {\n    final temp = await Directory.systemTemp.createTemp('centra-source-');\n",
    "  Future<PreparedSource> prepare(\n    SourceConfig config, {\n    SshConnectionSecrets? sshSecrets,\n  }) async {\n    final temp = await Directory.systemTemp.createTemp('centra-source-');\n",
)
replace_once(
    'lib/src/core/source.dart',
    "      case SourceType.ssh:\n        final target = '${config.user}@${config.host}';\n        final args = <String>[\n          '-p',\n          config.port.toString(),\n          if ((config.identityFile ?? '').isNotEmpty) ...<String>[\n            '-i',\n            config.identityFile!\n          ],\n          '--',\n          target,\n          'tar',\n          '-C',\n          config.root,\n          '-cf',\n          '-',\n          '.',\n        ];\n        return ('ssh', args);\n",
    "      case SourceType.ssh:\n        throw UnsupportedError('SSH snapshots use SshSourceProvider.');\n",
)
replace_once(
    'lib/src/core/source.dart',
    "  Future<PreparedSource> prepare(SourceConfig config) async {\n    final createArguments = <String>[\n",
    "  Future<PreparedSource> prepare(\n    SourceConfig config, {\n    SshConnectionSecrets? sshSecrets,\n  }) async {\n    final createArguments = <String>[\n",
)
replace_once(
    'lib/src/core/source.dart',
    "          SourceType.ssh:\n              ArchiveSourceProvider(type: SourceType.ssh, runner: runner),\n",
    "          SourceType.ssh: const SshSourceProvider(),\n",
)

replace_once(
    'lib/src/core/scanner.dart',
    "import 'source.dart';\n",
    "import 'source.dart';\nimport 'ssh_connection.dart';\n",
)
replace_once(
    'lib/src/core/scanner.dart',
    "  Future<ScanResult> scan(\n    CentraProfile profile, {\n    ScanProgressCallback? onProgress,\n  }) async {\n",
    "  Future<ScanResult> scan(\n    CentraProfile profile, {\n    ScanProgressCallback? onProgress,\n    SshConnectionSecrets? sshSecrets,\n  }) async {\n",
)
replace_once(
    'lib/src/core/scanner.dart',
    "        .provider(profile.source.type)\n        .prepare(profile.source);\n",
    "        .provider(profile.source.type)\n        .prepare(profile.source, sshSecrets: sshSecrets);\n",
)

replace_once(
    'lib/centra.dart',
    "export 'src/core/source.dart';\n",
    "export 'src/core/source.dart';\nexport 'src/core/ssh_connection.dart';\n",
)

replace_once(
    'lib/src/app/cli.dart',
    "import '../core/storage.dart';\n",
    "import '../core/storage.dart';\nimport '../core/ssh_connection.dart';\n",
)
replace_once(
    'lib/src/app/cli.dart',
    "          ..addOption('password-env',\n              help: 'Environment variable containing the ZIP password.')\n",
    "          ..addOption('password-env',\n              help: 'Environment variable containing the ZIP password.')\n          ..addOption('ssh-password-env',\n              help: 'Environment variable containing the SSH password.')\n          ..addOption('ssh-key-passphrase-env',\n              help: 'Environment variable containing the SSH key passphrase.')\n",
)
replace_once(
    'lib/src/app/cli.dart',
    "          ..addOption('manifest',\n              abbr: 'm', help: 'Approved manifest file.', mandatory: true)\n          ..addFlag('json',\n",
    "          ..addOption('manifest',\n              abbr: 'm', help: 'Approved manifest file.', mandatory: true)\n          ..addOption('ssh-password-env',\n              help: 'Environment variable containing the SSH password.')\n          ..addOption('ssh-key-passphrase-env',\n              help: 'Environment variable containing the SSH key passphrase.')\n          ..addFlag('json',\n",
)
replace_once(
    'lib/src/app/cli.dart',
    "    final scan = await scanner.scan(\n      profile,\n      onProgress: (progress) {\n",
    "    final sshSecrets = _sshSecretsFromResults(results);\n    final scan = await scanner.scan(\n      profile,\n      sshSecrets: sshSecrets,\n      onProgress: (progress) {\n",
)
replace_once(
    'lib/src/app/cli.dart',
    "    final current = (await scanner.scan(profile)).manifest;\n",
    "    final current = (await scanner.scan(\n      profile,\n      sshSecrets: _sshSecretsFromResults(results),\n    ))\n        .manifest;\n",
)

# Add helper before the final class closing helper section.
replace_once(
    'lib/src/app/cli.dart',
    "  String? _passwordFromEnvironment(String? variable) {\n",
    "  SshConnectionSecrets? _sshSecretsFromResults(ArgResults results) {\n    final passwordVariable = results.options.contains('ssh-password-env')\n        ? results['ssh-password-env'] as String?\n        : null;\n    final passphraseVariable =\n        results.options.contains('ssh-key-passphrase-env')\n            ? results['ssh-key-passphrase-env'] as String?\n            : null;\n    final password = _passwordFromEnvironment(passwordVariable);\n    final passphrase = _passwordFromEnvironment(passphraseVariable);\n    if (password == null && passphrase == null) return null;\n    return SshConnectionSecrets(\n      password: password,\n      keyPassphrase: passphrase,\n    );\n  }\n\n  String? _passwordFromEnvironment(String? variable) {\n",
)
