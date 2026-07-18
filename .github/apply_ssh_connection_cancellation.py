from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Pattern not found: {label}')
    return text.replace(old, new, 1)


path = Path('lib/src/core/ssh_connection.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    '''    required this.secrets,
  });
''',
    '''    required this.secrets,
    this.connectionId,
    this.connectionName,
  });
''',
    'selection saved connection constructor',
)
text = replace_once(
    text,
    '''  final SshConnectionSecrets secrets;
}
''',
    '''  final SshConnectionSecrets secrets;
  final String? connectionId;
  final String? connectionName;
}
''',
    'selection saved connection fields',
)
text = replace_once(
    text,
    '''    bool acceptUnknownHost = false,
  }) async {
''',
    '''    bool acceptUnknownHost = false,
    ScanCancellationToken? cancellationToken,
  }) async {
''',
    'SSH connect cancellation parameter',
)
text = replace_once(
    text,
    '''    final identities = await _loadIdentities(config, secrets);
''',
    '''    cancellationToken?.throwIfCancelled();
    final identities = await _loadIdentities(config, secrets);
''',
    'SSH connect initial cancellation',
)
text = replace_once(
    text,
    '''    final socket = await SSHSocket.connect(
      config.host!,
      config.port,
      timeout: Duration(seconds: config.connectTimeoutSeconds),
    );
    late final SSHClient client;
    try {
''',
    '''    final socketFuture = SSHSocket.connect(
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
''',
    'SSH cancellable socket',
)
text = replace_once(
    text,
    '''      await client.authenticated;
''',
    '''      removeCancellation = cancellationToken?.addListener(() {
        socket.destroy();
        client.close();
      });
      if (cancellationToken == null) {
        await client.authenticated;
      } else {
        await cancellationToken.race(client.authenticated);
      }
''',
    'SSH cancellable authentication',
)
text = replace_once(
    text,
    '''      final sftp = await client.sftp();
''',
    '''      final sftp = cancellationToken == null
          ? await client.sftp()
          : await cancellationToken.race(client.sftp());
      removeCancellation?.call();
      removeCancellation = null;
''',
    'SSH cancellable SFTP initialization',
)
text = replace_once(
    text,
    '''    } catch (_) {
      socket.destroy();
      rethrow;
    }
''',
    '''    } catch (_) {
      removeCancellation?.call();
      socket.destroy();
      rethrow;
    }
''',
    'SSH cancellation cleanup',
)
path.write_text(text, encoding='utf-8')
