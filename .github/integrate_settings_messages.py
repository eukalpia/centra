from pathlib import Path

path = Path('lib/src/i18n/messages.dart')
text = path.read_text(encoding='utf-8')
old = """      'bytes': 'Bytes',
      'keyboardHelp':
"""
new = """      'bytes': 'Bytes',
      'theme': 'Appearance',
      'defaultVerificationMode': 'Default verification mode',
      'fullVerification': 'Full verification',
      'fastVerification': 'Fast verification · weaker',
      'confirmRootScan': 'Confirm before scanning a filesystem root',
      'confirmDestructiveActions': 'Confirm destructive actions',
      'save': 'Save',
      'keyboardHelp':
"""
if old not in text:
    raise SystemExit('English messages anchor not found')
text = text.replace(old, new, 1)
old = """      'bytes': 'Байты',
      'keyboardHelp':
"""
new = """      'bytes': 'Байты',
      'theme': 'Оформление',
      'defaultVerificationMode': 'Режим проверки по умолчанию',
      'fullVerification': 'Полная проверка',
      'fastVerification': 'Быстрая проверка · слабее',
      'confirmRootScan': 'Подтверждать сканирование корня файловой системы',
      'confirmDestructiveActions': 'Подтверждать опасные действия',
      'save': 'Сохранить',
      'keyboardHelp':
"""
if old not in text:
    raise SystemExit('Russian messages anchor not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
