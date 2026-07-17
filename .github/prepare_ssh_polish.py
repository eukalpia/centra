from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Pattern not found in {path}: {old[:160]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/src/tui/ssh_source_picker.dart',
    "          _field(\n            strings('passwordHint'),\n            password,\n            passwordFocus,\n            '••••••••',\n          ),\n",
    "          _field(\n            strings('passwordHint'),\n            password,\n            passwordFocus,\n            '••••••••',\n            obscureText: true,\n          ),\n",
)
replace_once(
    'lib/src/tui/ssh_source_picker.dart',
    "                child: _field(\n                  strings('passphrase'),\n                  passphrase,\n                  passphraseFocus,\n                  'optional',\n                ),\n",
    "                child: _field(\n                  strings('passphrase'),\n                  passphrase,\n                  passphraseFocus,\n                  'optional',\n                  obscureText: true,\n                ),\n",
)
replace_once(
    'lib/src/tui/ssh_source_picker.dart',
    "  Widget _field(\n    String label,\n    TextEditingController controller,\n    FocusNode node,\n    String placeholder,\n  ) {\n",
    "  Widget _field(\n    String label,\n    TextEditingController controller,\n    FocusNode node,\n    String placeholder, {\n    bool obscureText = false,\n  }) {\n",
)
replace_once(
    'lib/src/tui/ssh_source_picker.dart',
    "              placeholder: placeholder,\n              style: const TextStyle(color: _sshText),\n",
    "              placeholder: placeholder,\n              obscureText: obscureText,\n              style: const TextStyle(color: _sshText),\n",
)

replace_once(
    'lib/src/app/cli.dart',
    "      'ssh': await _executableAvailable('ssh'),\n      'tar': await _executableAvailable('tar'),\n      'docker': await _executableAvailable('docker'),\n",
    "      'sshTransport': 'built-in SFTP',\n      'externalSshRequired': false,\n      'docker': await _executableAvailable('docker'),\n",
)

replace_once(
    'lib/src/core/scanner.dart',
    "      modifiedAt:\n          profile.captureModificationTimes ? stat.modified.toUtc() : null,\n      mode: profile.capturePermissions ? stat.mode : null,\n",
    "      modifiedAt: profile.source.type == SourceType.ssh\n          ? null\n          : profile.captureModificationTimes\n              ? stat.modified.toUtc()\n              : null,\n      mode: profile.source.type == SourceType.ssh\n          ? null\n          : profile.capturePermissions\n              ? stat.mode\n              : null,\n",
)
