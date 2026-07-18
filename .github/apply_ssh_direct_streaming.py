from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Pattern not found: {label}')
    return text.replace(old, new, 1)


path = Path('lib/src/core/path_policy.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    '''  bool shouldTraverseDirectory(String relativePath) {
''',
    '''  String? matchingExclusion(String relativePath, {bool directory = false}) {
    final path = normalizeRelativePath(relativePath);
    if (path.isEmpty) return null;
    if (!includeHiddenFiles &&
        path.split('/').any((segment) => segment.startsWith('.'))) {
      return '<hidden>';
    }
    for (final pattern in excludePatterns) {
      final matches = directory
          ? pattern.matchesDirectory(path)
          : pattern.matches(path);
      if (matches) return pattern.source;
    }
    return null;
  }

  bool shouldTraverseDirectory(String relativePath) {
''',
    'path policy matching exclusion',
)
path.write_text(text, encoding='utf-8')


path = Path('lib/src/core/ssh_connection.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    "import 'dart:io';\n",
    "import 'dart:io';\nimport 'dart:typed_data';\n",
    'typed data import',
)
text = replace_once(
    text,
    "import 'profile.dart';\n",
    "import 'profile.dart';\nimport 'scan_control.dart';\nimport 'ssh_inventory.dart';\n",
    'SSH scan imports',
)
text = replace_once(
    text,
    '''  Future<SshSnapshot> downloadSnapshot(
''',
    r'''  Future<SshInventoryResult> inventoryRemote(
    String remoteRoot, {
    required PathPolicy pathPolicy,
    required ScanLimits limits,
    required SymlinkPolicy symlinkPolicy,
    required ReadErrorPolicy readErrorPolicy,
    required int readRetryCount,
    required ScanCancellationToken cancellationToken,
    ScanProgressCallback? onProgress,
    bool countExcludedContents = true,
    bool skipVirtualFileSystems = true,
  }) async {
    _checkOpen();
    final stopwatch = Stopwatch()..start();
    final root = normalizeSshPath(
      await cancellationToken.race(_sftp.absolute(remoteRoot)),
    );
    final files = <SshRemoteEntry>[];
    final issues = <ScanIssue>[];
    final exclusionCounts = <String, ({int files, int bytes})>{};
    var directories = 0;
    var skipped = 0;
    var totalBytes = 0;
    var observedEntries = 0;

    void countExclusion(String pattern, int bytes) {
      final current = exclusionCounts[pattern];
      exclusionCounts[pattern] = (
        files: (current?.files ?? 0) + 1,
        bytes: (current?.bytes ?? 0) + bytes,
      );
      skipped++;
    }

    void report(String? currentPath) {
      onProgress?.call(
        ScanProgress(
          phase: 'ssh-inventory',
          discovered: files.length,
          completed: files.length,
          totalBytes: totalBytes,
          currentPath: currentPath,
          directories: directories,
          skipped: skipped,
          readErrors: issues.length,
          expectedBytes: totalBytes,
          elapsed: stopwatch.elapsed,
        ),
      );
    }

    Future<T?> perform<T>(
      String path,
      Future<T> Function() operation,
    ) async {
      final attempts = readErrorPolicy == ReadErrorPolicy.retry
          ? readRetryCount + 1
          : 1;
      Object? lastError;
      for (var attempt = 1; attempt <= attempts; attempt++) {
        cancellationToken.throwIfCancelled();
        try {
          return await cancellationToken.race(
            operation().timeout(
              Duration(seconds: limits.fileTimeoutSeconds),
            ),
          );
        } on ScanCancelledException {
          rethrow;
        } on Object catch (error) {
          lastError = error;
          if (attempt < attempts) continue;
        }
      }
      if (readErrorPolicy == ReadErrorPolicy.stop) {
        Error.throwWithStackTrace(lastError!, StackTrace.current);
      }
      issues.add(
        ScanIssue(
          path: path,
          code: lastError.runtimeType.toString(),
          message: lastError.toString(),
          attempts: attempts,
        ),
      );
      return null;
    }

    Future<void> walk(
      String remoteDirectory,
      String relativeDirectory,
      int depth, {
      String? inheritedExclusion,
    }) async {
      cancellationToken.throwIfCancelled();
      if (depth > limits.maximumDepth) {
        throw FileSystemException(
          'Remote directory depth exceeds the configured safety limit.',
          remoteDirectory,
        );
      }
      final names = await perform<List<SftpName>>(
        remoteDirectory,
        () => _sftp.listdir(remoteDirectory),
      );
      if (names == null) return;
      for (final name in names) {
        cancellationToken.throwIfCancelled();
        if (name.filename == '.' || name.filename == '..') continue;
        if (!_safeRemoteName(name.filename)) {
          throw FormatException('Unsafe SFTP entry name: ${name.filename}');
        }
        observedEntries++;
        if (observedEntries > limits.maximumFiles) {
          throw FileSystemException(
            'Remote source exceeds the configured entry limit.',
            root,
          );
        }
        final remotePath = normalizeSshPath(
          p.posix.join(remoteDirectory, name.filename),
        );
        final relativePath = relativeDirectory.isEmpty
            ? name.filename
            : p.posix.join(relativeDirectory, name.filename);
        if (skipVirtualFileSystems &&
            isSshVirtualFileSystemPath(root, relativePath)) {
          countExclusion('<virtual-filesystem>', name.attr.size ?? 0);
          continue;
        }
        final ownExclusion = inheritedExclusion ??
            pathPolicy.matchingExclusion(
              relativePath,
              directory: name.attr.isDirectory,
            );

        if (name.attr.isDirectory) {
          if (ownExclusion != null && !countExcludedContents) {
            countExclusion(ownExclusion, 0);
            continue;
          }
          if (ownExclusion == null) directories++;
          await walk(
            remotePath,
            relativePath,
            depth + 1,
            inheritedExclusion: ownExclusion,
          );
          continue;
        }

        if (name.attr.isSymbolicLink) {
          if (ownExclusion != null) {
            countExclusion(ownExclusion, name.attr.size ?? 0);
            continue;
          }
          if (symlinkPolicy == SymlinkPolicy.skip) {
            countExclusion('<symlink>', name.attr.size ?? 0);
            continue;
          }
          final target = await perform<String>(
            relativePath,
            () => _sftp.readlink(remotePath),
          );
          if (target == null) continue;
          final bytes = utf8.encode(target).length;
          files.add(
            SshRemoteEntry(
              path: relativePath,
              remotePath: remotePath,
              size: bytes,
              modifiedAt: _sftpModifiedAt(name.attr.modifyTime),
              mode: name.attr.mode?.value,
              isLink: true,
              symlinkTarget: target,
            ),
          );
          totalBytes += bytes;
          continue;
        }

        if (!name.attr.isFile) {
          countExclusion('<special-file>', name.attr.size ?? 0);
          continue;
        }
        if (ownExclusion != null || !pathPolicy.allows(relativePath)) {
          countExclusion(ownExclusion ?? '<policy>', name.attr.size ?? 0);
          continue;
        }
        final size = name.attr.size ?? 0;
        if (limits.maximumFileBytes > 0 && size > limits.maximumFileBytes) {
          countExclusion('<maximum-file-size>', size);
          issues.add(
            ScanIssue(
              path: relativePath,
              code: 'maximum_file_size',
              message: 'File exceeds the configured maximum file size.',
            ),
          );
          continue;
        }
        if (limits.maximumTotalBytes > 0 &&
            totalBytes + size > limits.maximumTotalBytes) {
          throw FileSystemException(
            'Remote source exceeds the configured total byte limit.',
            remotePath,
          );
        }
        files.add(
          SshRemoteEntry(
            path: relativePath,
            remotePath: remotePath,
            size: size,
            modifiedAt: _sftpModifiedAt(name.attr.modifyTime),
            mode: name.attr.mode?.value,
            isLink: false,
          ),
        );
        totalBytes += size;
        if (observedEntries % 100 == 0) report(relativePath);
      }
    }

    report(root);
    await walk(root, '', 0);
    files.sort((left, right) => left.path.compareTo(right.path));
    final exclusions = exclusionCounts.entries
        .map(
          (entry) => ExclusionEstimate(
            pattern: entry.key,
            files: entry.value.files,
            bytes: entry.value.bytes,
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => right.bytes.compareTo(left.bytes));
    report(null);
    return SshInventoryResult(
      root: root,
      entries: files,
      directories: directories,
      skipped: skipped,
      totalBytes: totalBytes,
      exclusions: exclusions,
      issues: issues,
    );
  }

  Future<SshStreamBatch<T>> streamRemoteFiles<T>(
    List<SshRemoteEntry> entries, {
    required int workerCount,
    required Duration fileTimeout,
    required ReadErrorPolicy readErrorPolicy,
    required int readRetryCount,
    required int unstableRetryCount,
    required ScanCancellationToken cancellationToken,
    required Future<T> Function(
      SshRemoteEntry entry,
      Stream<Uint8List> stream,
      int attempt,
    ) consume,
    ScanProgressCallback? onProgress,
  }) async {
    _checkOpen();
    final stopwatch = Stopwatch()..start();
    final clients = <SftpClient>[_sftp];
    final results = <SshStreamedFileResult<T>>[];
    final issues = <ScanIssue>[];
    var nextIndex = 0;
    var completed = 0;
    var transferredBytes = 0;
    var unstableFiles = 0;
    Object? firstError;
    StackTrace? firstStackTrace;
    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);

    final effectiveWorkers = workerCount.clamp(1, 8);
    for (var index = 1; index < effectiveWorkers; index++) {
      try {
        clients.add(
          await cancellationToken.race(
            _client.sftp().timeout(fileTimeout),
          ),
        );
      } on Object {
        break;
      }
    }

    void report(String? path, {bool force = false}) {
      final now = DateTime.now();
      if (!force && now.difference(lastProgressAt).inMilliseconds < 100) return;
      lastProgressAt = now;
      onProgress?.call(
        ScanProgress(
          phase: 'ssh-download',
          discovered: entries.length,
          completed: completed,
          totalBytes: transferredBytes,
          currentPath: path,
          readErrors: issues.length,
          unstableFiles: unstableFiles,
          transferredBytes: transferredBytes,
          expectedBytes: entries.fold<int>(0, (sum, entry) => sum + entry.size),
          elapsed: stopwatch.elapsed,
        ),
      );
    }

    final removeCancellationListener = cancellationToken.addListener(() {
      for (final client in clients) {
        client.close();
      }
    });

    Future<void> worker(SftpClient client) async {
      while (firstError == null) {
        cancellationToken.throwIfCancelled();
        final index = nextIndex++;
        if (index >= entries.length) return;
        final entry = entries[index];
        final maximumReadAttempts = readErrorPolicy == ReadErrorPolicy.retry
            ? readRetryCount + 1
            : 1;
        var readAttempt = 0;
        var unstableAttempt = 0;
        Object? lastReadError;
        var accepted = false;

        while (!accepted && firstError == null) {
          cancellationToken.throwIfCancelled();
          readAttempt++;
          SftpFile? file;
          try {
            if (entry.isLink) {
              final bytes = Uint8List.fromList(
                utf8.encode(entry.symlinkTarget ?? ''),
              );
              final value = await consume(entry, Stream<Uint8List>.value(bytes), readAttempt);
              transferredBytes += bytes.length;
              results.add(
                SshStreamedFileResult<T>(
                  entry: entry,
                  value: value,
                  bytesRead: bytes.length,
                  unstable: false,
                  attempts: readAttempt,
                  beforeSize: bytes.length,
                  afterSize: bytes.length,
                  beforeModifiedAt: entry.modifiedAt,
                  afterModifiedAt: entry.modifiedAt,
                ),
              );
              accepted = true;
              continue;
            }

            final before = await cancellationToken.race(
              client.stat(entry.remotePath).timeout(fileTimeout),
            );
            file = await cancellationToken.race(
              client.open(entry.remotePath).timeout(fileTimeout),
            );
            var fileBytes = 0;
            final stream = file.read().map((chunk) {
              cancellationToken.throwIfCancelled();
              fileBytes += chunk.length;
              transferredBytes += chunk.length;
              report(entry.path);
              return chunk;
            });
            final value = await cancellationToken.race(
              consume(entry, stream, readAttempt).timeout(fileTimeout),
            );
            await file.close();
            file = null;
            final after = await cancellationToken.race(
              client.stat(entry.remotePath).timeout(fileTimeout),
            );
            final unstable = before.size != after.size ||
                before.modifyTime != after.modifyTime ||
                before.mode?.value != after.mode?.value;
            if (unstable && unstableAttempt < unstableRetryCount) {
              unstableAttempt++;
              continue;
            }
            if (unstable) unstableFiles++;
            results.add(
              SshStreamedFileResult<T>(
                entry: entry,
                value: value,
                bytesRead: fileBytes,
                unstable: unstable,
                attempts: readAttempt,
                beforeSize: before.size,
                afterSize: after.size,
                beforeModifiedAt: _sftpModifiedAt(before.modifyTime),
                afterModifiedAt: _sftpModifiedAt(after.modifyTime),
              ),
            );
            if (unstable) {
              issues.add(
                ScanIssue(
                  path: entry.path,
                  code: 'unstable_file',
                  message: 'File changed while it was being read.',
                  attempts: readAttempt,
                ),
              );
            }
            accepted = true;
          } on ScanCancelledException {
            rethrow;
          } on Object catch (error, stackTrace) {
            await file?.close();
            cancellationToken.throwIfCancelled();
            lastReadError = error;
            if (readAttempt < maximumReadAttempts) continue;
            final issue = ScanIssue(
              path: entry.path,
              code: error.runtimeType.toString(),
              message: error.toString(),
              attempts: readAttempt,
            );
            issues.add(issue);
            if (readErrorPolicy == ReadErrorPolicy.stop) {
              firstError ??= error;
              firstStackTrace ??= stackTrace;
            }
            accepted = true;
          }
        }
        if (lastReadError != null && readErrorPolicy == ReadErrorPolicy.stop) {
          return;
        }
        completed++;
        report(entry.path, force: True);
      }
    }

    try {
      report(null, force: true);
      await Future.wait(clients.map(worker));
      cancellationToken.throwIfCancelled();
      if (firstError != null) {
        Error.throwWithStackTrace(firstError!, firstStackTrace!);
      }
      results.sort((left, right) => left.entry.path.compareTo(right.entry.path));
      issues.sort((left, right) => left.path.compareTo(right.path));
      report(null, force: true);
      return SshStreamBatch<T>(
        files: results,
        issues: issues,
        transferredBytes: transferredBytes,
        unstableFiles: unstableFiles,
      );
    } finally {
      removeCancellationListener();
      for (final client in clients.skip(1)) {
        client.close();
      }
    }
  }

  Future<SshSnapshot> downloadSnapshot(
''',
    'insert direct SSH inventory and streaming',
)
text = text.replace('report(entry.path, force: True);', 'report(entry.path, force: true);')
if '_sftpModifiedAt' not in text:
    raise SystemExit('direct streaming insertion failed')
helper_anchor = '''String normalizeSshPath(String path) {
'''
helper = '''DateTime? _sftpModifiedAt(int? secondsSinceEpoch) =>
    secondsSinceEpoch == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            secondsSinceEpoch * 1000,
            isUtc: true,
          );

'''
text = replace_once(text, helper_anchor, helper + helper_anchor, 'SFTP time helper')
path.write_text(text, encoding='utf-8')
