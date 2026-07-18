from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Pattern not found: {label}')
    return text.replace(old, new, 1)


path = Path('lib/src/core/profile.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    "import 'algorithm_registry.dart';\n",
    "import 'algorithm_registry.dart';\nimport 'scan_control.dart';\n",
    'profile scan control import',
)
text = replace_once(
    text,
    '''    this.keepAliveSeconds = 10,
    this.container,
''',
    '''    this.keepAliveSeconds = 10,
    this.sshConnectionId,
    this.sshConnectionName,
    this.container,
''',
    'source connection constructor fields',
)
text = replace_once(
    text,
    '''  final int keepAliveSeconds;
  final String? container;
''',
    '''  final int keepAliveSeconds;
  final String? sshConnectionId;
  final String? sshConnectionName;
  final String? container;
''',
    'source connection fields',
)
text = replace_once(
    text,
    '''        if (type == SourceType.ssh) 'keepAliveSeconds': keepAliveSeconds,
        if (container != null) 'container': container,
''',
    '''        if (type == SourceType.ssh) 'keepAliveSeconds': keepAliveSeconds,
        if (sshConnectionId != null) 'sshConnectionId': sshConnectionId,
        if (sshConnectionName != null) 'sshConnectionName': sshConnectionName,
        if (container != null) 'container': container,
''',
    'source connection json',
)
text = replace_once(
    text,
    '''        keepAliveSeconds: json['keepAliveSeconds'] as int? ?? 10,
        container: json['container'] as String?,
''',
    '''        keepAliveSeconds: json['keepAliveSeconds'] as int? ?? 10,
        sshConnectionId: json['sshConnectionId'] as String?,
        sshConnectionName: json['sshConnectionName'] as String?,
        container: json['container'] as String?,
''',
    'source connection from json',
)
text = replace_once(
    text,
    '''    required this.createdAt,
    required this.updatedAt,
  });
''',
    '''    required this.createdAt,
    required this.updatedAt,
    this.verificationMode = VerificationMode.full,
    this.readErrorPolicy,
    this.readRetryCount = 2,
    this.unstableRetryCount = 1,
    this.limits = const ScanLimits(),
    this.trustedBaselineManifest,
    this.trustedBaselineSignature,
    this.trustedPublicKey,
    this.trustedSigner,
    this.releaseCommit,
    this.releaseBuild,
  });
''',
    'profile optional runtime fields',
)
text = replace_once(
    text,
    '''  final DateTime createdAt;
  final DateTime updatedAt;

  List<String> validate() {
''',
    '''  final DateTime createdAt;
  final DateTime updatedAt;
  final VerificationMode verificationMode;
  final ReadErrorPolicy? readErrorPolicy;
  final int readRetryCount;
  final int unstableRetryCount;
  final ScanLimits limits;
  final String? trustedBaselineManifest;
  final String? trustedBaselineSignature;
  final String? trustedPublicKey;
  final String? trustedSigner;
  final String? releaseCommit;
  final String? releaseBuild;

  ReadErrorPolicy get effectiveReadErrorPolicy =>
      readErrorPolicy ??
      (failOnReadError ? ReadErrorPolicy.stop : ReadErrorPolicy.continueScan);

  List<String> validate() {
''',
    'profile runtime fields',
)
text = replace_once(
    text,
    '''    if (workerCount < 1 || workerCount > 64)
      errors.add('Worker count must be between 1 and 64.');
    errors
      ..addAll(source.validate())
      ..addAll(output.validate());
''',
    '''    if (workerCount < 1 || workerCount > 64)
      errors.add('Worker count must be between 1 and 64.');
    if (readRetryCount < 0 || readRetryCount > 20) {
      errors.add('Read retry count must be between 0 and 20.');
    }
    if (unstableRetryCount < 0 || unstableRetryCount > 10) {
      errors.add('Unstable file retry count must be between 0 and 10.');
    }
    if (trustedBaselineSignature != null && trustedBaselineManifest == null) {
      errors.add('A trusted signature requires a baseline manifest.');
    }
    if (trustedPublicKey != null && trustedBaselineSignature == null) {
      errors.add('A trusted public key requires a signature document.');
    }
    errors
      ..addAll(source.validate())
      ..addAll(output.validate())
      ..addAll(limits.validate());
''',
    'profile validation policies',
)
text = replace_once(
    text,
    "        'schema': 'centra.profile.v1',\n",
    "        'schema': 'centra.profile.v2',\n",
    'profile schema v2',
)
text = replace_once(
    text,
    '''        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
''',
    '''        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'verificationMode': verificationMode.wireName,
        'readErrorPolicy': effectiveReadErrorPolicy.wireName,
        'readRetryCount': readRetryCount,
        'unstableRetryCount': unstableRetryCount,
        'limits': limits.toJson(),
        if (trustedBaselineManifest != null)
          'trustedBaselineManifest': trustedBaselineManifest,
        if (trustedBaselineSignature != null)
          'trustedBaselineSignature': trustedBaselineSignature,
        if (trustedPublicKey != null) 'trustedPublicKey': trustedPublicKey,
        if (trustedSigner != null) 'trustedSigner': trustedSigner,
        if (releaseCommit != null) 'releaseCommit': releaseCommit,
        if (releaseBuild != null) 'releaseBuild': releaseBuild,
      };
''',
    'profile runtime json',
)
text = replace_once(
    text,
    '''    if (json['schema'] != 'centra.profile.v1') {
      throw FormatException('Unsupported profile schema: ${json['schema']}');
    }
''',
    '''    final schema = json['schema'];
    if (schema != 'centra.profile.v1' && schema != 'centra.profile.v2') {
      throw FormatException('Unsupported profile schema: $schema');
    }
''',
    'profile schema compatibility',
)
text = replace_once(
    text,
    '''      updatedAt: DateTime.parse(json['updatedAt']! as String),
    );
''',
    '''      updatedAt: DateTime.parse(json['updatedAt']! as String),
      verificationMode: VerificationModeName.parse(
        json['verificationMode'] as String? ?? 'full',
      ),
      readErrorPolicy: json['readErrorPolicy'] == null
          ? null
          : ReadErrorPolicyName.parse(json['readErrorPolicy']! as String),
      readRetryCount: json['readRetryCount'] as int? ?? 2,
      unstableRetryCount: json['unstableRetryCount'] as int? ?? 1,
      limits: ScanLimits.fromJson(
        (json['limits'] as Map<Object?, Object?>? ?? const <Object?, Object?>{})
            .cast<String, Object?>(),
      ),
      trustedBaselineManifest: json['trustedBaselineManifest'] as String?,
      trustedBaselineSignature: json['trustedBaselineSignature'] as String?,
      trustedPublicKey: json['trustedPublicKey'] as String?,
      trustedSigner: json['trustedSigner'] as String?,
      releaseCommit: json['releaseCommit'] as String?,
      releaseBuild: json['releaseBuild'] as String?,
    );
''',
    'profile runtime from json',
)
path.write_text(text, encoding='utf-8')


path = Path('lib/src/core/storage.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    "import 'profile.dart';\n",
    "import 'profile.dart';\nimport 'scan_control.dart';\n",
    'storage scan control import',
)
text = replace_once(
    text,
    '''  File get settingsFile => File(p.join(configDirectory.path, 'settings.json'));
  Directory get historyDirectory =>
''',
    '''  File get settingsFile => File(p.join(configDirectory.path, 'settings.json'));
  File get sshConnectionsFile =>
      File(p.join(configDirectory.path, 'ssh-connections.json'));
  Directory get historyDirectory =>
''',
    'ssh connections path',
)
start = text.index('class CentraSettings {')
end = text.index('\nclass AtomicFileWriter', start)
settings_class = '''class CentraSettings {
  const CentraSettings({
    required this.locale,
    required this.theme,
    required this.confirmDestructiveActions,
    this.onboardingCompleted = false,
    this.confirmBeforeRootScan = true,
    this.defaultVerificationMode = VerificationMode.full,
    this.lastProfileId,
  });

  final String locale;
  final String theme;
  final bool confirmDestructiveActions;
  final bool onboardingCompleted;
  final bool confirmBeforeRootScan;
  final VerificationMode defaultVerificationMode;
  final String? lastProfileId;

  static const defaults = CentraSettings(
    locale: 'en',
    theme: 'auto',
    confirmDestructiveActions: true,
  );

  CentraSettings copyWith({
    String? locale,
    String? theme,
    bool? confirmDestructiveActions,
    bool? onboardingCompleted,
    bool? confirmBeforeRootScan,
    VerificationMode? defaultVerificationMode,
    String? lastProfileId,
  }) =>
      CentraSettings(
        locale: locale ?? this.locale,
        theme: theme ?? this.theme,
        confirmDestructiveActions:
            confirmDestructiveActions ?? this.confirmDestructiveActions,
        onboardingCompleted:
            onboardingCompleted ?? this.onboardingCompleted,
        confirmBeforeRootScan:
            confirmBeforeRootScan ?? this.confirmBeforeRootScan,
        defaultVerificationMode:
            defaultVerificationMode ?? this.defaultVerificationMode,
        lastProfileId: lastProfileId ?? this.lastProfileId,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 'centra.settings.v2',
        'locale': locale,
        'theme': theme,
        'confirmDestructiveActions': confirmDestructiveActions,
        'onboardingCompleted': onboardingCompleted,
        'confirmBeforeRootScan': confirmBeforeRootScan,
        'defaultVerificationMode': defaultVerificationMode.wireName,
        if (lastProfileId != null) 'lastProfileId': lastProfileId,
      };

  factory CentraSettings.fromJson(Map<String, Object?> json) {
    final schema = json['schema'];
    if (schema != 'centra.settings.v1' && schema != 'centra.settings.v2') {
      throw FormatException('Unsupported settings schema: $schema');
    }
    return CentraSettings(
      locale: json['locale'] as String? ?? 'en',
      theme: json['theme'] as String? ?? 'auto',
      confirmDestructiveActions:
          json['confirmDestructiveActions'] as bool? ?? true,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      confirmBeforeRootScan: json['confirmBeforeRootScan'] as bool? ?? true,
      defaultVerificationMode: VerificationModeName.parse(
        json['defaultVerificationMode'] as String? ?? 'full',
      ),
      lastProfileId: json['lastProfileId'] as String?,
    );
  }
}
'''
text = text[:start] + settings_class + text[end:]
path.write_text(text, encoding='utf-8')


path = Path('lib/centra.dart')
text = path.read_text(encoding='utf-8')
exports = [
    "export 'src/core/hashing.dart';",
    "export 'src/core/scan_control.dart';",
    "export 'src/core/ssh_inventory.dart';",
    "export 'src/core/ssh_library.dart';",
]
for export in exports:
    if export not in text:
        text += export + '\n'
path.write_text(text, encoding='utf-8')
