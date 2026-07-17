from pathlib import Path

path = Path('lib/src/core/ssh_connection.dart')
text = path.read_text(encoding='utf-8')
needle = "import 'dart:convert';\n"
if needle not in text:
    raise SystemExit('dart:convert import not found')
text = text.replace(needle, "import 'dart:async';\nimport 'dart:convert';\n", 1)
path.write_text(text, encoding='utf-8')
