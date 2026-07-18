from pathlib import Path

path = Path('lib/src/tui/settings_panel.dart')
text = path.read_text(encoding='utf-8')
old = """            Wrap(
              spacing: 1,
              children: CentraStrings.locales
                  .map(
                    (value) => _choice(
                      value.nativeName,
                      locale == value.code,
                      () => setState(() => locale = value.code),
                    ),
                  )
                  .toList(growable: false),
            ),
"""
new = """            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: CentraStrings.locales
                  .map(
                    (value) => _choice(
                      value.nativeName,
                      locale == value.code,
                      () => setState(() => locale = value.code),
                    ),
                  )
                  .toList(growable: false),
            ),
"""
if old not in text:
    raise SystemExit('Settings language layout not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
