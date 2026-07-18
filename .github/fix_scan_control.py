from pathlib import Path

path = Path('lib/src/core/scan_control.dart')
text = path.read_text(encoding='utf-8')
old = 'return Future<T>.any(<Future<T>>['
new = 'return Future.any<T>(<Future<T>>['
if old not in text:
    raise SystemExit('Future.any call not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
