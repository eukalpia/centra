from pathlib import Path

path = Path('lib/src/core/ssh_connection.dart')
text = path.read_text(encoding='utf-8')
old = """      for (final name in names) {
        cancellationToken?.throwIfCancelled();
        cancellationToken.throwIfCancelled();
"""
new = """      for (final name in names) {
        cancellationToken.throwIfCancelled();
"""
if old not in text:
    raise SystemExit('Duplicate cancellation check not found')
text = text.replace(old, new, 1)
old = """            file = await cancellationToken.race(
              client.open(entry.remotePath).timeout(fileTimeout),
            );
            var fileBytes = 0;
            final stream = file.read().map((chunk) {
"""
new = """            final openedFile = await cancellationToken.race(
              client.open(entry.remotePath).timeout(fileTimeout),
            );
            file = openedFile;
            var fileBytes = 0;
            final stream = openedFile.read().map((chunk) {
"""
if old not in text:
    raise SystemExit('Nullable SFTP read block not found')
text = text.replace(old, new, 1)
old = """            await file.close();
            file = null;
"""
new = """            await openedFile.close();
            file = null;
"""
if old not in text:
    raise SystemExit('Nullable SFTP close block not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
