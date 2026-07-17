import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import 'profile.dart';

class SshConnectionSecrets {
  const SshConnectionSecrets({
    this.password,
    this.keyPassphrase,
  });

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

  Future<SshSnapshot> downloadSnapshot(
    String remoteRoot, {
    int maximumEntries = 2000000,
    int maximumDepth = 256,
  }) async {
    _checkOpen();
    final root = normalizeSshPath(await _sftp.absolute(remoteRoot));
    final destination = await Directory.systemTemp.createTemp('centra-ssh-');
    var files = 0;
    var directories = 0;
    var symlinks = 0;
    var entries = 0;

    Future<void> copyDirectory(
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
      final names = await _sftp.listdir(remoteDirectory);
      for (final name in names) {
        if (name.filename == '.' || name.filename == '..') continue;
        if (!_safeRemoteName(name.filename)) {
          throw FormatException(
            'Unsafe SFTP entry name: ${name.filename}',
          );
        }
        entries++;
        if (entries > maximumEntries) {
          throw FileSystemException(
            'Remote snapshot exceeds the configured entry limit.',
            root,
          );
        }
        final remotePath =
            normalizeSshPath(p.posix.join(remoteDirectory, name.filename));
        final relativePath = relativeDirectory.isEmpty
            ? name.filename
            : p.posix.join(relativeDirectory, name.filename);
        final localPath = _safeLocalPath(destination.path, relativePath);

        if (name.attr.isDirectory) {
          await Directory(localPath).create(recursive: true);
          directories++;
          await copyDirectory(remotePath, relativePath, depth + 1);
          continue;
        }
        if (name.attr.isSymbolicLink) {
          final target = await _sftp.readlink(remotePath);
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

        await Directory(p.dirname(localPath)).create(recursive: true);
        final sink = File(localPath).openWrite();
        try {
          await _sftp.download(
            remotePath,
            sink,
            closeDestination: true,
          );
        } catch (_) {
          await sink.close();
          rethrow;
        }
        files++;
      }
    }

    try {
      await copyDirectory(root, '', 0);
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
  }) async {
    if (config.type != SourceType.ssh) {
      throw ArgumentError.value(
          config.type, 'config.type', 'Expected SSH source.');
    }
    final validation = config.validate();
    final connectionErrors = validation
        .where((message) => message != 'SSH host key fingerprint is required.')
        .toList(growable: false);
    if (connectionErrors.isNotEmpty) {
      throw FormatException(connectionErrors.join('\n'));
    }

    final identities = await _loadIdentities(config, secrets);
    if (config.sshAuthMethod.usesPassword && !secrets.hasPassword) {
      throw const FormatException(
          'SSH password is required for this connection.');
    }

    String? observedKeyType;
    String? observedFingerprint;
    final socket = await SSHSocket.connect(
      config.host!,
      config.port,
      timeout: Duration(seconds: config.connectTimeoutSeconds),
    );
    late final SSHClient client;
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
      await client.authenticated;
      if (observedFingerprint == null || observedKeyType == null) {
        throw StateError('SSH server did not provide a host key fingerprint.');
      }
      final sftp = await client.sftp();
      return SshConnection._(
        client: client,
        sftp: sftp,
        config: config,
        hostKeyType: observedKeyType!,
        hostKeyFingerprint: observedFingerprint!,
      );
    } catch (_) {
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
          'SSH private key file does not exist.', identityPath);
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
        'Remote snapshot path escapes destination: $relative');
  }
  return output;
}
