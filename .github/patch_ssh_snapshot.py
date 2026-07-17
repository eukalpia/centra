from pathlib import Path
import re

path = Path('lib/src/core/ssh_connection.dart')
text = path.read_text(encoding='utf-8')
text = text.replace("import 'profile.dart';", "import 'path_policy.dart';\nimport 'profile.dart';", 1)

anchor = '''class SshSnapshot {
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
'''
addition = anchor + '''

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
'''
if anchor not in text:
    raise SystemExit('SshSnapshot anchor not found')
text = text.replace(anchor, addition, 1)

pattern = re.compile(r'  Future<SshSnapshot> downloadSnapshot\(.*?\n  \}\n\n  Future<void> close\(\) async \{', re.S)
replacement = '''  Future<SshSnapshot> downloadSnapshot(
    String remoteRoot, {
    int maximumEntries = 2000000,
    int maximumDepth = 256,
    int workerCount = 4,
    Duration fileTimeout = const Duration(minutes: 2),
    PathPolicy? pathPolicy,
    bool skipVirtualFileSystems = true,
    SshSnapshotProgressCallback? onProgress,
  }) async {
    _checkOpen();
    final root = normalizeSshPath(await _sftp.absolute(remoteRoot));
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

  Future<void> close() async {'''
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit(f'downloadSnapshot matched {count} times')
path.write_text(text, encoding='utf-8')
