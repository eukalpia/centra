from pathlib import Path

path = Path('lib/src/core/scanner.dart')
text = path.read_text(encoding='utf-8')
old = "import 'ssh_connection.dart';\n"
new = "import 'ssh_connection.dart';\nimport 'ssh_inventory.dart';\n"
if old not in text:
    raise SystemExit('SSH connection import not found')
text = text.replace(old, new, 1)
old = """    stopwatch.stop();
    return buildScanResult(
      toolVersion: centraVersion,
      manifestId: _manifestId(_clock().toUtc()),
      generatedAt: _clock().toUtc(),
"""
new = """    stopwatch.stop();
    final generatedAt = _clock().toUtc();
    return buildScanResult(
      toolVersion: centraVersion,
      manifestId: _manifestId(generatedAt),
      generatedAt: generatedAt,
"""
if old not in text:
    raise SystemExit('SSH result timestamp block not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
