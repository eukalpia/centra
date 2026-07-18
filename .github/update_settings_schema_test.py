from pathlib import Path

path = Path('test/storage_test.dart')
text = path.read_text(encoding='utf-8')
old = "contains('centra.settings.v1')"
new = "contains('centra.settings.v2')"
if old not in text:
    raise SystemExit('Legacy settings schema assertion not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
