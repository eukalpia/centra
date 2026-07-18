import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import 'path_policy.dart';
import 'profile.dart';
import 'scan_control.dart';
import 'ssh_inventory.dart';

class SshConnectionSecrets {
  const SshConnectionSecrets({this.password, this.keyPassphrase});

  final String? password;
  final String? keyPassphrase;

  bool get hasPassword => (password ?? '').isNotEmpty;
  bool get hasKeyPassphrase => (keyPassphrase ?? '').isNotEmpty;
}

class SshDirectoryEntry {
  const SshDirectoryEntry({
    required this.name,
    required this.path,
    required this.isParent,
  });

  final String name;
  final String path;
  final bool isParent;
}

class SshDirectoryListing {
  const SshDirectoryListing({
    required this.path,
    required this.entries,
    required this.parentPath,
  });

  final String path;
  final List<SshDirectoryEntry> entries;
  final String? parentPath;
}

class SshSourceSelection {
  const SshSourceSelection({
    required this.host,
    required this.port,
    required this.user,
    required this.path,
    required this.authMethod,
    required this.identityFile,
    required this.hostKeyType,
    required this.hostKeyFingerprint,
    required this.connectTimeoutSeconds,
    required this.keepAliveSeconds,
    required this.serverVersion,
    required this.secrets,
    this.connectionId,
    this.connectionName,
  });

  final String host;
  final int port;
  final String user;
  final String path;
  final SshAuthMethod authMethod;
  final String? identityFile;
  final String hostKeyType;
  final String hostKeyFingerprint;
  final int connectTimeoutSeconds;
  final int keepAliveSeconds;
  final String? serverVersion;
  final SshConnectionSecrets secrets;
  final String? connectionId;
  final String? connectionName;
}

class SshSnapshot {
  const SshSnapshot({
    required this.directory,
    required this.files,
    required this.directories,
    required this.symlinks,
  });

  final Directory directory;
  final int files;
  final int directories;
  final int symlinks;
}

class SshSnapshotProgress {
  const SshSnapshotProgress({
    required this.phase,
    required this.discovered,
    required this.completed,
    required this.directories,
    required this.symlinks,
    required this.totalBytes,
    this.currentPath,
  });

  final String phase;
  final int discovered;
  final int completed;
  final int directories;
  final int symlinks;
  final int totalBytes;
  final String? currentPath;
}

typedef SshSnapshotProgressCallback = void Function(SshSnapshotProgress value);

class _SshDownloadJob {
  const _SshDownloadJob(this.remotePath, this.relativePath, this.localPath);

  final String remotePath;
  final String relativePath;
  final String localPath;
}

const _virtualSshRootDirectories = <String>{'proc', 'sys', 'dev', 'run'};

bool isSshVirtualFileSystemPath(String remoteRoot, String relativePath) {
  if (normalizeSshPath(remoteRoot) != '/') return false;
  final normalized = normalizeRelativePath(relativePath);
  if (normalized.isEmpty) return false;
  return _virtualSshRootDirectories.contains(normalized.split('/').first);
}

class SshConnection {
  SshConnection._({
    required SSHClient client,
    required SftpClient sftp,
    required this.config,
    required this.hostKeyType,
    required this.hostKeyFingerprint,
  })  : _client = client,
        _sftp = sftp;

  final SSHClient _client;
  final SftpClient _sftp;
  final SourceConfig config;
  final String hostKeyType;
  final String hostKeyFingerprint;
  var _closed = false;

  String? get serverVersion => _client.remoteVersion;

  Future<SSHSession> openShell({
    required int columns,
    required int rows,
  }) async {
    _checkOpen();
    return _client.shell(
      pty: SSHPtyConfig(width: columns, height: rows),
    );
  }

  Future<SshDirectoryListing> listDirectories(String path) async {
    _checkOpen();
    final normalized = normalizeSshPath(await _sftp.absolute(path));
    final children = await _sftp.listdir(normalized);
    final entries = <SshDirectoryEntry>[];
    for (final child in children) {
      final name = child.filename;
      if (name == '.' || name == '..' || !_safeRemoteName(name)) continue;
      var directory = child.attr.isDirectory;
      if (!directory && child.attr.isSymbolicLink) {
        try {
          directory = (await _sftp.stat(
            p.posix.join(normalized, name),
          ))
              .isDirectory;
        } on Object {
          directory = false;
        }
      }
      if (!directory) continue;
      entries.add(
        SshDirectoryEntry(
          name: name,
          path: normalizeSshPath(p.posix.join(normalized, name)),
          isParent: false,
        ),
      );
    }
    entries.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    final parent = sshParentPath(normalized);
    return SshDirectoryListing(
      path: normalized,
      entries: <SshDirectoryEntry>[
        if (parent != null)
          SshDirectoryEntry(name: '..', path: parent, isParent: true),
        ...entries,
      ],
      parentPath: parent,
    );
  }

  Future<SshInventoryResult> inventoryRemote(
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
      final attempts =
          readErrorPolicy == ReadErrorPolicy.retry ? readRetryCount + 1 : 1;
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
        final maximumReadAttempts =
            readErrorPolicy == ReadErrorPolicy.retry ? readRetryCount + 1 : 1;
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
              final value = await consume(
                  entry, Stream<Uint8List>.value(bytes), readAttempt);
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
            final openedFile = await cancellationToken.race(
              client.open(entry.remotePath).timeout(fileTimeout),
            );
            file = openedFile;
            var fileBytes = 0;
            final stream = openedFile.read().map((chunk) {
              cancellationToken.throwIfCancelled();
              fileBytes += chunk.length;
              transferredBytes += chunk.length;
              report(entry.path);
              return chunk;
            });
            final value = await cancellationToken.race(
              consume(entry, stream, readAttempt).timeout(fileTimeout),
            );
            await openedFile.close();
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
        report(entry.path, force: true);
      }
    }

    try {
      report(null, force: true);
      await Future.wait(clients.map(worker));
      cancellationToken.throwIfCancelled();
      if (firstError != null) {
        Error.throwWithStackTrace(firstError!, firstStackTrace!);
      }
      results
          .sort((left, right) => left.entry.path.compareTo(right.entry.path));
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
    String remoteRoot, {
    int maximumEntries = 2000000,
    int maximumDepth = 256,
    int workerCount = 4,
    Duration fileTimeout = const Duration(minutes: 2),
    PathPolicy? pathPolicy,
    bool skipVirtualFileSystems = true,
    SshSnapshotProgressCallback? onProgress,
    ScanCancellationToken? cancellationToken,
  }) async {
    _checkOpen();
    cancellationToken?.throwIfCancelled();
    final root = normalizeSshPath(
      cancellationToken == null
          ? await _sftp.absolute(remoteRoot)
          : await cancellationToken.race(_sftp.absolute(remoteRoot)),
    );
    final destination = await Directory.systemTemp.createTemp('centra-ssh-');
    final jobs = <_SshDownloadJob>[];
    var files = 0;
    var directories = 0;
    var symlinks = 0;
    var entries = 0;
    var completed = 0;
    var totalBytes = 0;

    void report(String phase, [String? currentPath]) {
      onProgress?.call(SshSnapshotProgress(
        phase: phase,
        discovered: jobs.length,
        completed: completed,
        directories: directories,
        symlinks: symlinks,
        totalBytes: totalBytes,
        currentPath: currentPath,
      ));
    }

    Future<List<SftpName>> listDirectory(String remoteDirectory) async {
      try {
        return await _sftp.listdir(remoteDirectory).timeout(fileTimeout);
      } on TimeoutException {
        throw TimeoutException(
          'Timed out while listing remote directory $remoteDirectory.',
          fileTimeout,
        );
      }
    }

    Future<void> inventoryDirectory(
      String remoteDirectory,
      String relativeDirectory,
      int depth,
    ) async {
      if (depth > maximumDepth) {
        throw FileSystemException(
          'Remote directory depth exceeds the configured safety limit.',
          remoteDirectory,
        );
      }
      final names = await listDirectory(remoteDirectory);
      for (final name in names) {
        if (name.filename == '.' || name.filename == '..') continue;
        if (!_safeRemoteName(name.filename)) {
          throw FormatException('Unsafe SFTP entry name: ${name.filename}');
        }
        entries++;
        if (entries > maximumEntries) {
          throw FileSystemException(
            'Remote snapshot exceeds the configured entry limit.',
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
          continue;
        }
        final localPath = _safeLocalPath(destination.path, relativePath);

        if (name.attr.isDirectory) {
          if (pathPolicy != null &&
              !pathPolicy.shouldTraverseDirectory(relativePath)) {
            continue;
          }
          await Directory(localPath).create(recursive: true);
          directories++;
          if (entries % 50 == 0) report('ssh-inventory', relativePath);
          await inventoryDirectory(remotePath, relativePath, depth + 1);
          continue;
        }
        if (name.attr.isSymbolicLink) {
          if (pathPolicy != null && !pathPolicy.allows(relativePath)) continue;
          final target = await _sftp.readlink(remotePath).timeout(fileTimeout);
          await Directory(p.dirname(localPath)).create(recursive: true);
          try {
            await Link(localPath).create(target);
          } on FileSystemException {
            await File('$localPath.centra-symlink').writeAsString(target);
          }
          symlinks++;
          continue;
        }
        if (!name.attr.isFile) continue;
        if (pathPolicy != null && !pathPolicy.allows(relativePath)) continue;
        jobs.add(_SshDownloadJob(remotePath, relativePath, localPath));
        if (jobs.length % 50 == 0) report('ssh-inventory', relativePath);
      }
    }

    final clients = <SftpClient>[_sftp];
    try {
      report('ssh-inventory', root);
      await inventoryDirectory(root, '', 0);
      report('ssh-download', root);

      final effectiveWorkers = workerCount < 1
          ? 1
          : workerCount > 8
              ? 8
              : workerCount;
      for (var index = 1; index < effectiveWorkers; index++) {
        try {
          clients.add(await _client.sftp().timeout(fileTimeout));
        } on Object {
          break;
        }
      }

      var nextIndex = 0;
      Object? firstError;
      StackTrace? firstStackTrace;

      Future<void> worker(SftpClient client) async {
        while (firstError == null) {
          cancellationToken?.throwIfCancelled();
          final index = nextIndex++;
          if (index >= jobs.length) return;
          final job = jobs[index];
          final file = File(job.localPath);
          await file.parent.create(recursive: true);
          final sink = file.openWrite();
          try {
            await client
                .download(job.remotePath, sink, closeDestination: false)
                .timeout(fileTimeout);
            await sink.flush();
          } on Object catch (error, stackTrace) {
            if (error is TimeoutException) client.close();
            firstError ??= error is TimeoutException
                ? TimeoutException(
                    'Timed out while downloading ${job.relativePath}.',
                    fileTimeout,
                  )
                : error;
            firstStackTrace ??= stackTrace;
          } finally {
            await sink.close();
          }
          if (firstError != null) {
            if (await file.exists()) await file.delete();
            return;
          }
          totalBytes += await file.length();
          files++;
          completed++;
          report('ssh-download', job.relativePath);
        }
      }

      await Future.wait(clients.map(worker));
      if (firstError != null) {
        Error.throwWithStackTrace(firstError!, firstStackTrace!);
      }
      report('ssh-download');
      return SshSnapshot(
        directory: destination,
        files: files,
        directories: directories,
        symlinks: symlinks,
      );
    } catch (_) {
      if (await destination.exists()) {
        await destination.delete(recursive: true);
      }
      rethrow;
    } finally {
      for (final client in clients.skip(1)) {
        client.close();
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _sftp.close();
    _client.close();
    try {
      await _client.done.timeout(const Duration(seconds: 2));
    } on Object {
      // The transport has already been closed locally.
    }
  }

  void _checkOpen() {
    if (_closed) throw StateError('SSH connection is already closed.');
  }
}

class SshConnectionService {
  const SshConnectionService();

  Future<SshConnection> connect(
    SourceConfig config, {
    SshConnectionSecrets secrets = const SshConnectionSecrets(),
    bool acceptUnknownHost = false,
    ScanCancellationToken? cancellationToken,
  }) async {
    if (config.type != SourceType.ssh) {
      throw ArgumentError.value(
        config.type,
        'config.type',
        'Expected SSH source.',
      );
    }
    final validation = config.validate();
    final connectionErrors = validation
        .where((message) => message != 'SSH host key fingerprint is required.')
        .toList(growable: false);
    if (connectionErrors.isNotEmpty) {
      throw FormatException(connectionErrors.join('\n'));
    }

    cancellationToken?.throwIfCancelled();
    final identities = await _loadIdentities(config, secrets);
    if (config.sshAuthMethod.usesPassword && !secrets.hasPassword) {
      throw const FormatException(
        'SSH password is required for this connection.',
      );
    }

    String? observedKeyType;
    String? observedFingerprint;
    final socketFuture = SSHSocket.connect(
      config.host!,
      config.port,
      timeout: Duration(seconds: config.connectTimeoutSeconds),
    );
    final socket = cancellationToken == null
        ? await socketFuture
        : await cancellationToken.race(socketFuture);
    late final SSHClient client;
    void Function()? removeCancellation;
    try {
      client = SSHClient(
        socket,
        username: config.user!,
        identities: identities.isEmpty ? null : identities,
        onPasswordRequest:
            config.sshAuthMethod.usesPassword ? () => secrets.password : null,
        onUserInfoRequest: config.sshAuthMethod.usesPassword
            ? (request) => List<String>.filled(
                  request.prompts.length,
                  secrets.password ?? '',
                )
            : null,
        onVerifyHostKey: (type, fingerprintBytes) {
          final fingerprint = utf8.decode(fingerprintBytes);
          observedKeyType = type;
          observedFingerprint = fingerprint;
          final pinned = (config.hostKeyFingerprint ?? '').trim();
          if (pinned.isNotEmpty) return pinned == fingerprint;
          return acceptUnknownHost;
        },
        keepAliveInterval: config.keepAliveSeconds == 0
            ? null
            : Duration(seconds: config.keepAliveSeconds),
        handshakeTimeout: Duration(seconds: config.connectTimeoutSeconds),
        authTimeout: Duration(seconds: config.connectTimeoutSeconds),
        ident: 'Centra_0.1',
      );
      removeCancellation = cancellationToken?.addListener(() {
        socket.destroy();
        client.close();
      });
      if (cancellationToken == null) {
        await client.authenticated;
      } else {
        await cancellationToken.race(client.authenticated);
      }
      if (observedFingerprint == null || observedKeyType == null) {
        throw StateError('SSH server did not provide a host key fingerprint.');
      }
      final sftp = cancellationToken == null
          ? await client.sftp()
          : await cancellationToken.race(client.sftp());
      removeCancellation?.call();
      removeCancellation = null;
      return SshConnection._(
        client: client,
        sftp: sftp,
        config: config,
        hostKeyType: observedKeyType!,
        hostKeyFingerprint: observedFingerprint!,
      );
    } catch (_) {
      removeCancellation?.call();
      socket.destroy();
      rethrow;
    }
  }

  Future<List<SSHKeyPair>> _loadIdentities(
    SourceConfig config,
    SshConnectionSecrets secrets,
  ) async {
    if (!config.sshAuthMethod.usesPrivateKey) return const <SSHKeyPair>[];
    final identityPath = expandUserPath(config.identityFile ?? '');
    if (identityPath.isEmpty) {
      throw const FormatException('SSH private key file is required.');
    }
    final file = File(identityPath);
    if (!await file.exists()) {
      throw FileSystemException(
        'SSH private key file does not exist.',
        identityPath,
      );
    }
    final pem = await file.readAsString();
    if (SSHKeyPair.isEncryptedPem(pem) && !secrets.hasKeyPassphrase) {
      throw const FormatException('SSH private key passphrase is required.');
    }
    try {
      return SSHKeyPair.fromPem(pem, secrets.keyPassphrase);
    } on Object catch (error) {
      throw FormatException('Unable to read SSH private key: $error');
    }
  }
}

DateTime? _sftpModifiedAt(int? secondsSinceEpoch) => secondsSinceEpoch == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(
        secondsSinceEpoch * 1000,
        isUtc: true,
      );

String normalizeSshPath(String path) {
  var value = path.trim().replaceAll('\\', '/');
  if (value.isEmpty) return '/';
  if (!value.startsWith('/')) value = '/$value';
  value = p.posix.normalize(value);
  return value == '.' ? '/' : value;
}

String? sshParentPath(String path) {
  final normalized = normalizeSshPath(path);
  if (normalized == '/') return null;
  final parent = p.posix.dirname(normalized);
  return parent == '.' ? '/' : parent;
}

String expandUserPath(String path) {
  final value = path.trim();
  if (value.isEmpty || value == '~') {
    return value == '~' ? _homeDirectory() ?? value : value;
  }
  if (!value.startsWith('~/') && !value.startsWith('~\\')) return value;
  final home = _homeDirectory();
  if (home == null) return value;
  return p.join(home, value.substring(2));
}

String? _homeDirectory() =>
    Platform.environment['USERPROFILE'] ??
    Platform.environment['HOME'] ??
    Platform.environment['HOMEPATH'];

bool _safeRemoteName(String name) =>
    name.isNotEmpty &&
    name != '.' &&
    name != '..' &&
    !name.contains('/') &&
    !name.contains('\\') &&
    !name.contains('\u0000');

String _safeLocalPath(String root, String relative) {
  final segments = p.posix
      .split(relative)
      .where((segment) => segment.isNotEmpty && segment != '.')
      .toList(growable: false);
  if (segments.any((segment) => segment == '..' || !_safeRemoteName(segment))) {
    throw FormatException('Unsafe remote snapshot path: $relative');
  }
  final output = p.joinAll(<String>[root, ...segments]);
  if (!p.isWithin(root, output)) {
    throw FormatException(
      'Remote snapshot path escapes destination: $relative',
    );
  }
  return output;
}
