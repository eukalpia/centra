from pathlib import Path

path = Path('lib/src/tui/wizard_state.dart')
text = path.read_text(encoding='utf-8')
old = """  int connectTimeoutSeconds = 15;
  int keepAliveSeconds = 10;
  String container = '';
"""
new = """  int connectTimeoutSeconds = 15;
  int keepAliveSeconds = 10;
  String sshConnectionId = '';
  String sshConnectionName = '';
  String container = '';
"""
if old not in text:
    raise SystemExit('Wizard SSH metadata fields anchor not found')
text = text.replace(old, new, 1)
old = """        keepAliveSeconds: keepAliveSeconds,
        container: container.trim().isEmpty ? null : container.trim(),
"""
new = """        keepAliveSeconds: keepAliveSeconds,
        sshConnectionId:
            sshConnectionId.trim().isEmpty ? null : sshConnectionId.trim(),
        sshConnectionName:
            sshConnectionName.trim().isEmpty ? null : sshConnectionName.trim(),
        container: container.trim().isEmpty ? null : container.trim(),
"""
if old not in text:
    raise SystemExit('Wizard SSH source metadata anchor not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
