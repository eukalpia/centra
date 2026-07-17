from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Pattern not found for {label}')
    return text.replace(old, new, 1)


path = Path('lib/src/core/path_policy.dart')
text = path.read_text(encoding='utf-8')
anchor = '''  bool allows(String relativePath) {
    final path = normalizeRelativePath(relativePath);
    if (path.isEmpty) return false;
    if (!includeHiddenFiles &&
        path.split('/').any((segment) => segment.startsWith('.'))) {
      return false;
    }
    final included = includePatterns.isEmpty ||
        includePatterns.any((pattern) => pattern.matches(path));
    if (!included) return false;
    return !excludePatterns.any((pattern) => pattern.matches(path));
  }
'''
text = replace_once(text, anchor, anchor + '''

  bool shouldTraverseDirectory(String relativePath) {
    final path = normalizeRelativePath(relativePath);
    if (path.isEmpty) return true;
    if (!includeHiddenFiles &&
        path.split('/').any((segment) => segment.startsWith('.'))) {
      return false;
    }
    final directoryPath = '$path/';
    return !excludePatterns.any(
      (pattern) => pattern.matches(path) || pattern.matches(directoryPath),
    );
  }
''', 'directory pruning')
path.write_text(text, encoding='utf-8')


path = Path('lib/src/core/source.dart')
text = path.read_text(encoding='utf-8')
old = '''  Future<PreparedSource> prepare(
    SourceConfig config, {
    SshConnectionSecrets? sshSecrets,
  });
'''
new = '''  Future<PreparedSource> prepare(
    SourceConfig config, {
    SshConnectionSecrets? sshSecrets,
    PathPolicy? pathPolicy,
    int workerCount = 4,
    SshSnapshotProgressCallback? onSshProgress,
  });
'''
text = replace_once(text, old, new, 'provider contract')
old = '''  Future<PreparedSource> prepare(
    SourceConfig config, {
    SshConnectionSecrets? sshSecrets,
  }) async {
'''
new = '''  Future<PreparedSource> prepare(
    SourceConfig config, {
    SshConnectionSecrets? sshSecrets,
    PathPolicy? pathPolicy,
    int workerCount = 4,
    SshSnapshotProgressCallback? onSshProgress,
  }) async {
'''
if text.count(old) != 4:
    raise SystemExit(f'Expected 4 provider overrides, found {text.count(old)}')
text = text.replace(old, new)
text = replace_once(
    text,
    '      final snapshot = await connection.downloadSnapshot(config.root);\n',
    '''      final snapshot = await connection.downloadSnapshot(
        config.root,
        pathPolicy: pathPolicy,
        workerCount: workerCount,
        onProgress: onSshProgress,
      );
''',
    'SSH provider options',
)
path.write_text(text, encoding='utf-8')


path = Path('lib/src/core/scanner.dart')
text = path.read_text(encoding='utf-8')
old = '''    final stopwatch = Stopwatch()..start();
    final prepared = await _sourceRegistry
        .provider(profile.source.type)
        .prepare(profile.source, sshSecrets: sshSecrets);
    try {
      final registry =
          AlgorithmRegistry(customAlgorithms: profile.customAlgorithms);
      final descriptors =
          profile.algorithmIds.map(registry.descriptor).toList(growable: false);
      final policy = PathPolicy(
        includes: profile.includePatterns,
        excludes: profile.excludePatterns,
        includeHiddenFiles: profile.includeHiddenFiles,
      );
'''
new = '''    final stopwatch = Stopwatch()..start();
    final registry =
        AlgorithmRegistry(customAlgorithms: profile.customAlgorithms);
    final descriptors =
        profile.algorithmIds.map(registry.descriptor).toList(growable: false);
    final policy = PathPolicy(
      includes: profile.includePatterns,
      excludes: profile.excludePatterns,
      includeHiddenFiles: profile.includeHiddenFiles,
    );
    onProgress?.call(
      ScanProgress(
        phase: profile.source.type == SourceType.ssh
            ? 'ssh-connect'
            : 'source-prepare',
        discovered: 0,
        completed: 0,
        totalBytes: 0,
        currentPath: profile.source.root,
      ),
    );
    final prepared = await _sourceRegistry.provider(profile.source.type).prepare(
          profile.source,
          sshSecrets: sshSecrets,
          pathPolicy: policy,
          workerCount: profile.workerCount,
          onSshProgress: onProgress == null
              ? null
              : (progress) => onProgress(
                    ScanProgress(
                      phase: progress.phase,
                      discovered: progress.discovered,
                      completed: progress.completed,
                      totalBytes: progress.totalBytes,
                      currentPath: progress.currentPath,
                    ),
                  ),
        );
    try {
'''
text = replace_once(text, old, new, 'scanner source progress')
path.write_text(text, encoding='utf-8')


path = Path('lib/src/tui/ssh_source_picker.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    "      'helpBrowser':\n          '↑↓ move  Enter open  Backspace parent  Space choose  R refresh  Esc back',\n",
    "      'helpBrowser':\n          '↑↓ move  Enter open  Backspace parent  Space choose  R refresh  Esc back',\n      'rootWarning':\n          'Scanning / can be very large. /proc, /sys, /dev and /run are skipped for safety.',\n",
    'English root warning',
)
text = replace_once(
    text,
    "      'helpBrowser':\n          '↑↓ выбор  Enter открыть  Backspace вверх  Space выбрать  R обновить  Esc назад',\n",
    "      'helpBrowser':\n          '↑↓ выбор  Enter открыть  Backspace вверх  Space выбрать  R обновить  Esc назад',\n      'rootWarning':\n          'Сканирование / может быть очень долгим. /proc, /sys, /dev и /run пропускаются для безопасности.',\n",
    'Russian root warning',
)
anchor = '''        Container(
          color: _sshSurfaceStrong,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            current?.path ?? '/',
            maxLines: 1,
            style: const TextStyle(color: _sshAccent),
          ),
        ),
        const SizedBox(height: 1),
'''
replacement = '''        Container(
          color: _sshSurfaceStrong,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            current?.path ?? '/',
            maxLines: 1,
            style: const TextStyle(color: _sshAccent),
          ),
        ),
        if ((current?.path ?? '/') == '/')
          Text(
            strings('rootWarning'),
            maxLines: 2,
            style: const TextStyle(color: _sshWarning),
          ),
        const SizedBox(height: 1),
'''
text = replace_once(text, anchor, replacement, 'root warning UI')
path.write_text(text, encoding='utf-8')


path = Path('test/path_policy_test.dart')
text = path.read_text(encoding='utf-8')
anchor = '''    test('honors explicit include patterns', () {
'''
addition = '''    test('prunes excluded directories before remote traversal', () {
      final policy = PathPolicy(
        includes: const <String>['**'],
        excludes: const <String>[
          'node_modules/**',
          '**/node_modules/**',
          '.git/**',
        ],
        includeHiddenFiles: true,
      );
      expect(policy.shouldTraverseDirectory('node_modules'), isFalse);
      expect(
        policy.shouldTraverseDirectory('apps/web/node_modules'),
        isFalse,
      );
      expect(policy.shouldTraverseDirectory('.git'), isFalse);
      expect(policy.shouldTraverseDirectory('lib'), isTrue);
    });

'''
text = replace_once(text, anchor, addition + anchor, 'directory pruning test')
path.write_text(text, encoding='utf-8')


path = Path('test/ssh_connection_test.dart')
text = path.read_text(encoding='utf-8')
anchor = '''    test('calculates parents without escaping the remote root', () {
      expect(sshParentPath('/srv/application'), '/srv');
      expect(sshParentPath('/srv'), '/');
      expect(sshParentPath('/'), isNull);
    });
'''
addition = anchor + '''

    test('skips virtual Linux filesystems only for a root scan', () {
      expect(isSshVirtualFileSystemPath('/', 'proc/1/status'), isTrue);
      expect(isSshVirtualFileSystemPath('/', 'sys/kernel'), isTrue);
      expect(isSshVirtualFileSystemPath('/', 'dev/null'), isTrue);
      expect(isSshVirtualFileSystemPath('/', 'run/lock'), isTrue);
      expect(isSshVirtualFileSystemPath('/', 'srv/application'), isFalse);
      expect(
        isSshVirtualFileSystemPath('/srv', 'proc/legitimate-file'),
        isFalse,
      );
    });
'''
text = replace_once(text, anchor, addition, 'virtual filesystem test')
path.write_text(text, encoding='utf-8')
