from pathlib import Path

path = Path('lib/src/tui/production_dashboard.dart')
text = path.read_text(encoding='utf-8')
needle = "import 'dart:io';\n\n"
if needle not in text:
    raise SystemExit('Unused dart:io import not found')
path.write_text(text.replace(needle, '', 1), encoding='utf-8')
