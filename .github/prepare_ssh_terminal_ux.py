from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Pattern not found in {path}: {old[:180]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


# Expose a real interactive shell on the authenticated transport.
replace_once(
    'lib/src/core/ssh_connection.dart',
    "  String? get serverVersion => _client.remoteVersion;\n\n  Future<SshDirectoryListing> listDirectories(String path) async {",
    "  String? get serverVersion => _client.remoteVersion;\n\n"
    "  Future<SSHSession> openShell({\n"
    "    required int columns,\n"
    "    required int rows,\n"
    "  }) async {\n"
    "    _checkOpen();\n"
    "    return _client.shell(\n"
    "      pty: SSHPtyConfig(width: columns, height: rows),\n"
    "    );\n"
    "  }\n\n"
    "  Future<SshDirectoryListing> listDirectories(String path) async {",
)

path = 'lib/src/tui/ssh_source_picker.dart'
replace_once(
    path,
    "import '../core/ssh_connection.dart';\n",
    "import '../core/ssh_connection.dart';\nimport 'ssh_terminal_controller.dart';\n",
)
replace_once(
    path,
    "      'refresh': 'Refresh',\n",
    "      'refresh': 'Refresh',\n"
    "      'terminal': 'Terminal',\n"
    "      'files': 'Files',\n"
    "      'openTerminal': 'Open terminal',\n"
    "      'terminalHelp': 'Ctrl+Shift+B files  Ctrl+Shift+R restart  PageUp/PageDown scroll',\n",
)
replace_once(
    path,
    "      'refresh': 'Обновить',\n",
    "      'refresh': 'Обновить',\n"
    "      'terminal': 'Терминал',\n"
    "      'files': 'Файлы',\n"
    "      'openTerminal': 'Открыть терминал',\n"
    "      'terminalHelp': 'Ctrl+Shift+B файлы  Ctrl+Shift+R перезапуск  PageUp/PageDown прокрутка',\n",
)
replace_once(
    path,
    "    this.initialAuthMethod = SshAuthMethod.privateKey,",
    "    this.initialAuthMethod = SshAuthMethod.password,",
)
replace_once(
    path,
    "  final keepAliveFocus = FocusNode(debugLabel: 'SSH keepalive');\n",
    "  final keepAliveFocus = FocusNode(debugLabel: 'SSH keepalive');\n"
    "  final directoryScroll = ScrollController();\n",
)
replace_once(
    path,
    "  var connecting = false;\n  String? error;\n",
    "  var connecting = false;\n"
    "  var terminalMode = false;\n"
    "  SshTerminalController? terminalController;\n"
    "  String? error;\n",
)
replace_once(
    path,
    "    identityFile = TextEditingController(\n        text: widget.initialIdentityFile ?? '~/.ssh/id_ed25519');",
    "    identityFile = TextEditingController(\n        text: widget.initialIdentityFile ?? '');",
)
replace_once(
    path,
    "  void dispose() {\n    connection?.close();",
    "  void dispose() {\n    terminalController?.dispose();\n    connection?.close();",
)
replace_once(
    path,
    "    for (final node in <FocusNode>[focus, ...fieldFocusNodes]) {\n      node.dispose();\n    }\n    super.dispose();",
    "    for (final node in <FocusNode>[focus, ...fieldFocusNodes]) {\n      node.dispose();\n    }\n    directoryScroll.dispose();\n    super.dispose();",
)
replace_once(
    path,
    "      setState(() {\n        listing = next;\n        selected = 0;\n        connecting = false;\n      });",
    "      setState(() {\n        listing = next;\n        selected = 0;\n        connecting = false;\n      });\n      _ensureSelectedVisible();",
)
replace_once(
    path,
    "  void _move(int delta) {\n    final entries = listing?.entries ?? const <SshDirectoryEntry>[];\n    if (entries.isEmpty) return;\n    setState(() {\n      selected = (selected + delta) % entries.length;\n      if (selected < 0) selected += entries.length;\n    });\n  }\n\n  Future<void> _activate() async {",
    "  void _move(int delta) {\n"
    "    final entries = listing?.entries ?? const <SshDirectoryEntry>[];\n"
    "    if (entries.isEmpty) return;\n"
    "    setState(() {\n"
    "      selected = (selected + delta) % entries.length;\n"
    "      if (selected < 0) selected += entries.length;\n"
    "    });\n"
    "    _ensureSelectedVisible();\n"
    "  }\n\n"
    "  void _jumpToIndex(int index) {\n"
    "    final entries = listing?.entries ?? const <SshDirectoryEntry>[];\n"
    "    if (entries.isEmpty) return;\n"
    "    setState(() => selected = index.clamp(0, entries.length - 1));\n"
    "    _ensureSelectedVisible();\n"
    "  }\n\n"
    "  void _ensureSelectedVisible() {\n"
    "    void ensure() => directoryScroll.ensureIndexVisible(index: selected);\n"
    "    try {\n"
    "      TerminalBinding.instance.addPostFrameCallback((_) => ensure());\n"
    "    } on Object {\n"
    "      ensure();\n"
    "    }\n"
    "  }\n\n"
    "  Future<void> _openTerminal() async {\n"
    "    final active = connection;\n"
    "    if (active == null || terminalMode) return;\n"
    "    setState(() {\n"
    "      terminalController = SshTerminalController(connection: active);\n"
    "      terminalMode = true;\n"
    "      error = null;\n"
    "    });\n"
    "  }\n\n"
    "  Future<void> _closeTerminal() async {\n"
    "    final controller = terminalController;\n"
    "    terminalController = null;\n"
    "    await controller?.dispose();\n"
    "    if (!mounted) return;\n"
    "    setState(() => terminalMode = false);\n"
    "    focus.requestFocus();\n"
    "    _ensureSelectedVisible();\n"
    "  }\n\n"
    "  bool _handleTerminalKey(KeyboardEvent event) {\n"
    "    if (event.matches(LogicalKey.keyB, ctrl: true, shift: true)) {\n"
    "      _closeTerminal();\n"
    "      return true;\n"
    "    }\n"
    "    if (event.matches(LogicalKey.keyR, ctrl: true, shift: true)) {\n"
    "      terminalController?.restart();\n"
    "      return true;\n"
    "    }\n"
    "    return false;\n"
    "  }\n\n"
    "  Future<void> _activate() async {",
)
replace_once(
    path,
    "  Future<void> _back() async {\n    if (!browsing) {",
    "  Future<void> _back() async {\n"
    "    if (terminalMode) {\n"
    "      await _closeTerminal();\n"
    "      return;\n"
    "    }\n"
    "    if (!browsing) {",
)
replace_once(
    path,
    "  Future<void> _choose() async {\n    final active = connection;",
    "  Future<void> _choose() async {\n    await _closeTerminal();\n    final active = connection;",
)
replace_once(
    path,
    "  Future<void> _cancel() async {\n    final active = connection;",
    "  Future<void> _cancel() async {\n    await _closeTerminal();\n    final active = connection;",
)
replace_once(
    path,
    "    if (event.logicalKey == LogicalKey.arrowDown) {\n      _move(1);\n      return true;\n    }",
    "    if (event.logicalKey == LogicalKey.arrowDown) {\n"
    "      _move(1);\n"
    "      return true;\n"
    "    }\n"
    "    if (event.logicalKey == LogicalKey.pageUp) {\n"
    "      final page = directoryScroll.viewportDimension > 1\n"
    "          ? directoryScroll.viewportDimension.floor() - 1\n"
    "          : 10;\n"
    "      _move(-page);\n"
    "      return true;\n"
    "    }\n"
    "    if (event.logicalKey == LogicalKey.pageDown) {\n"
    "      final page = directoryScroll.viewportDimension > 1\n"
    "          ? directoryScroll.viewportDimension.floor() - 1\n"
    "          : 10;\n"
    "      _move(page);\n"
    "      return true;\n"
    "    }\n"
    "    if (event.logicalKey == LogicalKey.home) {\n"
    "      _jumpToIndex(0);\n"
    "      return true;\n"
    "    }\n"
    "    if (event.logicalKey == LogicalKey.end) {\n"
    "      _jumpToIndex((listing?.entries.length ?? 1) - 1);\n"
    "      return true;\n"
    "    }",
)
replace_once(
    path,
    "          child: browsing ? _browser() : _form(),",
    "          child: terminalMode\n"
    "              ? _terminal()\n"
    "              : browsing\n"
    "                  ? _browser()\n"
    "                  : _form(),",
)
replace_once(
    path,
    "                    _field(strings('host'), host, hostFocus, '195.158.3.42')),
",
    "                    _field(strings('host'), host, hostFocus, 'server.example.com')),
",
)
replace_once(
    path,
    "        const Spacer(),\n        Row(\n          mainAxisAlignment: MainAxisAlignment.end,",
    "        const SizedBox(height: 1),\n        Row(\n          mainAxisAlignment: MainAxisAlignment.end,",
)
old_list = """                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: entries
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => GestureDetector(
                                      onTap: () {
                                        setState(() => selected = entry.key);
                                        _loadDirectory(entry.value.path);
                                      },
                                      child: Container(
                                        color: selected == entry.key
                                            ? _sshSurfaceStrong
                                            : null,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 1,
                                        ),
                                        child: Text(
                                          '${entry.value.isParent ? '↰' : '▸'} ${entry.value.name}',
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: selected == entry.key
                                                ? _sshAccent
                                                : _sshText,
                                            fontWeight: selected == entry.key
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),"""
new_list = """                        : ListView.builder(
                            controller: directoryScroll,
                            itemCount: entries.length,
                            itemExtent: 1,
                            lazy: false,
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return GestureDetector(
                                onTap: () {
                                  setState(() => selected = index);
                                  _ensureSelectedVisible();
                                  _loadDirectory(entry.path);
                                },
                                child: Container(
                                  color: selected == index
                                      ? _sshSurfaceStrong
                                      : null,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  child: Text(
                                    '${entry.isParent ? '↰' : '▸'} ${entry.name}',
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: selected == index
                                          ? _sshAccent
                                          : _sshText,
                                      fontWeight: selected == index
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),"""
replace_once(path, old_list, new_list)
replace_once(
    path,
    "            _button(\n              strings('refresh'),\n              () => _loadDirectory(current?.path ?? '/'),\n              muted: true,\n            ),\n            const Spacer(),",
    "            _button(\n"
    "              strings('refresh'),\n"
    "              () => _loadDirectory(current?.path ?? '/'),\n"
    "              muted: true,\n"
    "            ),\n"
    "            const SizedBox(width: 1),\n"
    "            _button(strings('openTerminal'), _openTerminal, muted: true),\n"
    "            const Spacer(),",
)
terminal_widget = """
  Widget _terminal() {
    final controller = terminalController!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text('● ', style: TextStyle(color: _sshSuccess)),
            Expanded(
              child: Text(
                '${user.text}@${host.text}:${port.text}',
                maxLines: 1,
                style: const TextStyle(
                  color: _sshText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(strings('terminal'), style: const TextStyle(color: _sshAccent)),
          ],
        ),
        const SizedBox(height: 1),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _sshSurface,
              border: BoxBorder.all(
                color: const Color(0x27313D),
                style: BoxBorderStyle.rounded,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: TerminalXterm(
              controller: controller,
              focused: true,
              autoStart: true,
              maxLines: 20000,
              onKeyEvent: _handleTerminalKey,
            ),
          ),
        ),
        const SizedBox(height: 1),
        Row(
          children: <Widget>[
            _button(strings('files'), _closeTerminal, muted: true),
            const Spacer(),
            Text(strings('terminalHelp'), style: const TextStyle(color: _sshMuted)),
          ],
        ),
      ],
    );
  }

"""
replace_once(path, "  Widget _field(\n", terminal_widget + "  Widget _field(\n")

# Keep public documentation aligned with the terminal and navigation behavior.
doc = Path('doc/ssh.md')
text = doc.read_text(encoding='utf-8')
text = text.replace(
    '- remote directory browsing with keyboard and mouse.\n',
    '- remote directory browsing with keyboard and mouse;\n'
    '- an interactive SSH terminal over the same authenticated connection.\n',
)
text = text.replace(
    '| `Esc` | Return to connection settings or cancel |\n',
    '| `Page Up` / `Page Down` | Move by one visible page and keep the selection visible |\n'
    '| `Home` / `End` | Jump to the first or last entry |\n'
    '| `Esc` | Return to connection settings or cancel |\n',
)
text += """

## Interactive terminal

After a connection succeeds, choose **Open terminal** from the remote browser. Centra opens a PTY-backed remote shell through the existing pure-Dart SSH transport; it does not start a local `ssh` process.

The terminal supports ANSI applications, command history, cursor keys, resize notifications, UTF-8 output, and scrollback. Use `Ctrl+Shift+B` to return to the file browser without closing the SSH connection and `Ctrl+Shift+R` to restart only the remote shell session.
"""
doc.write_text(text, encoding='utf-8')
