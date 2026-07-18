from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Pattern not found: {label}')
    return text.replace(old, new, 1)


path = Path('lib/src/core/ssh_connection.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    '''    SshSnapshotProgressCallback? onProgress,
  }) async {
    _checkOpen();
    final root = normalizeSshPath(await _sftp.absolute(remoteRoot));
''',
    '''    SshSnapshotProgressCallback? onProgress,
    ScanCancellationToken? cancellationToken,
  }) async {
    _checkOpen();
    cancellationToken?.throwIfCancelled();
    final root = normalizeSshPath(
      cancellationToken == null
          ? await _sftp.absolute(remoteRoot)
          : await cancellationToken.race(_sftp.absolute(remoteRoot)),
    );
''',
    'snapshot cancellation signature',
)
text = text.replace(
    '''      for (final name in names) {
''',
    '''      for (final name in names) {
        cancellationToken?.throwIfCancelled();
''',
    1,
)
text = replace_once(
    text,
    '''      Future<void> worker(SftpClient client) async {
        while (firstError == null) {
''',
    '''      Future<void> worker(SftpClient client) async {
        while (firstError == null) {
          cancellationToken?.throwIfCancelled();
''',
    'snapshot worker cancellation',
)
path.write_text(text, encoding='utf-8')
