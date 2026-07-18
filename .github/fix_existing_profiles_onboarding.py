from pathlib import Path

path = Path('lib/src/tui/centra_app.dart')
text = path.read_text(encoding='utf-8')
old = '        skipLanguageSelection: settings.onboardingCompleted,\n'
new = '        skipLanguageSelection: settings.onboardingCompleted || profiles.isNotEmpty,\n'
if old not in text:
    raise SystemExit('Wizard onboarding flag not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
