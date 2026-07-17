from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Pattern not found in {path}: {old[:160]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


path = 'lib/src/tui/centra_app.dart'

replace_once(
    path,
    "import '../core/storage.dart';\n",
    "import '../core/storage.dart';\nimport '../core/ssh_connection.dart';\n",
)
replace_once(
    path,
    "import 'folder_picker.dart';\n",
    "import 'folder_picker.dart';\nimport 'ssh_source_picker.dart';\n",
)
replace_once(
    path,
    "  late bool showWizard;\n",
    "  late bool showWizard;\n  final sshSecrets = <String, SshConnectionSecrets>{};\n",
)
replace_once(
    path,
    "  Future<void> _profileSaved(CentraProfile profile) async {\n    await widget.profileStore.save(profile);\n",
    "  Future<void> _profileSaved(\n    CentraProfile profile,\n    SshConnectionSecrets? secrets,\n  ) async {\n    await widget.profileStore.save(profile);\n    if (secrets != null) sshSecrets[profile.id] = secrets;\n",
)
replace_once(
    path,
    "      locale: settings.locale,\n      onNewProfile: () => setState(() => showWizard = true),\n",
    "      locale: settings.locale,\n      sshSecrets: sshSecrets,\n      onNewProfile: () => setState(() => showWizard = true),\n",
)
replace_once(
    path,
    "  final Future<void> Function(CentraProfile profile) onSaved;\n",
    "  final Future<void> Function(\n    CentraProfile profile,\n    SshConnectionSecrets? secrets,\n  ) onSaved;\n",
)
replace_once(
    path,
    "  SourceType? dockerPickerSourceType;\n  String? selectedDockerResourceTitle;\n",
    "  SourceType? dockerPickerSourceType;\n  String? selectedDockerResourceTitle;\n  var sshPickerOpen = false;\n  SshConnectionSecrets? sshConnectionSecrets;\n  String? selectedSshServerVersion;\n",
)
replace_once(
    path,
    "  bool _stepHasTextField(WizardStep candidate) =>\n",
    "  void _openSshPicker() {\n    _syncDraft();\n    setState(() {\n      error = null;\n      sshPickerOpen = true;\n    });\n  }\n\n  void _closeSshPicker() {\n    setState(() => sshPickerOpen = false);\n    wizardFocus.requestFocus();\n  }\n\n  void _selectSshSource(SshSourceSelection selection) {\n    host.text = selection.host;\n    port.text = selection.port.toString();\n    user.text = selection.user;\n    root.text = selection.path;\n    identityFile.text = selection.identityFile ?? '';\n    draft\n      ..sshAuthMethod = selection.authMethod\n      ..sshHostKeyPolicy = SshHostKeyPolicy.pinned\n      ..hostKeyType = selection.hostKeyType\n      ..hostKeyFingerprint = selection.hostKeyFingerprint\n      ..connectTimeoutSeconds = selection.connectTimeoutSeconds\n      ..keepAliveSeconds = selection.keepAliveSeconds;\n    sshConnectionSecrets = selection.secrets;\n    selectedSshServerVersion = selection.serverVersion;\n    _syncDraft();\n    setState(() {\n      error = null;\n      sshPickerOpen = false;\n    });\n    wizardFocus.requestFocus();\n  }\n\n  bool _stepHasTextField(WizardStep candidate) =>\n",
)
replace_once(
    path,
    "    if (folderPickerController != null || dockerPickerSourceType != null) {\n",
    "    if (folderPickerController != null ||\n        dockerPickerSourceType != null ||\n        sshPickerOpen) {\n",
)
replace_once(
    path,
    "            selectedDockerResourceTitle = null;\n          }\n          draft.sourceType = nextSource;\n",
    "            selectedDockerResourceTitle = null;\n            sshConnectionSecrets = null;\n            selectedSshServerVersion = null;\n            draft\n              ..hostKeyType = ''\n              ..hostKeyFingerprint = '';\n          }\n          draft.sourceType = nextSource;\n",
)
replace_once(
    path,
    "        await widget.onSaved(draft.toProfile());\n",
    "        await widget.onSaved(draft.toProfile(), sshConnectionSecrets);\n",
)
replace_once(
    path,
    "    final dockerSourceType = dockerPickerSourceType;\n",
    "    if (sshPickerOpen) {\n      return Stack(\n        children: <Widget>[\n          screen,\n          ModalBarrier(\n            color: const Color(0x000000).withAlpha(196),\n            obscure: false,\n            onDismiss: _closeSshPicker,\n          ),\n          Center(\n            child: SshSourcePicker(\n              locale: locale,\n              initialHost: host.text.trim(),\n              initialPort: int.tryParse(port.text.trim()) ?? 22,\n              initialUser: user.text.trim(),\n              initialPath: root.text.trim().isEmpty ? '/' : root.text.trim(),\n              initialAuthMethod: draft.sshAuthMethod,\n              initialIdentityFile: identityFile.text.trim().isEmpty\n                  ? null\n                  : identityFile.text.trim(),\n              initialFingerprint: draft.hostKeyFingerprint.trim().isEmpty\n                  ? null\n                  : draft.hostKeyFingerprint.trim(),\n              initialConnectTimeoutSeconds: draft.connectTimeoutSeconds,\n              initialKeepAliveSeconds: draft.keepAliveSeconds,\n              initialSecrets:\n                  sshConnectionSecrets ?? const SshConnectionSecrets(),\n              onSelected: _selectSshSource,\n              onCancel: _closeSshPicker,\n            ),\n          ),\n        ],\n      );\n    }\n\n    final dockerSourceType = dockerPickerSourceType;\n",
)
replace_once(
    path,
    "      case SourceType.ssh:\n        fields.addAll(<Widget>[\n          _field(strings('rootPath'), root, rootFocus, '/srv/application'),\n          _field(strings('host'), host, hostFocus, 'server.example.com'),\n          _field(strings('user'), user, userFocus, 'deploy'),\n          _field(strings('port'), port, portFocus, '22'),\n          _field(\n            strings('identityFile'),\n            identityFile,\n            identityFileFocus,\n            '~/.ssh/id_ed25519',\n          ),\n        ]);\n        break;\n",
    "      case SourceType.ssh:\n        fields.add(_sshSelectionPanel());\n        break;\n",
)
replace_once(
    path,
    "  Widget _dockerSelectionPanel(SourceType sourceType) {\n",
    "  Widget _sshSelectionPanel() {\n    final connected = host.text.trim().isNotEmpty &&\n        user.text.trim().isNotEmpty &&\n        root.text.trim().isNotEmpty &&\n        draft.hostKeyFingerprint.trim().isNotEmpty;\n    return Container(\n      decoration: BoxDecoration(\n        color: _surfaceStrong,\n        border: BoxBorder.all(\n          color: connected ? _accent : const Color(0x394453),\n          style: BoxBorderStyle.rounded,\n        ),\n      ),\n      padding: const EdgeInsets.all(1),\n      child: Column(\n        crossAxisAlignment: CrossAxisAlignment.stretch,\n        children: <Widget>[\n          Row(\n            children: <Widget>[\n              Text(\n                connected ? '● SSH' : '○ SSH',\n                style: TextStyle(\n                  color: connected ? _success : _muted,\n                  fontWeight: FontWeight.bold,\n                ),\n              ),\n              const Spacer(),\n              Text(\n                connected ? draft.sshAuthMethod.wireName : 'not configured',\n                style: const TextStyle(color: _muted),\n              ),\n            ],\n          ),\n          _ReviewRow(\n            strings('host'),\n            connected ? '${user.text}@${host.text}:${port.text}' : '—',\n          ),\n          _ReviewRow(strings('rootPath'), connected ? root.text : '—'),\n          if (connected)\n            _ReviewRow(\n              'Fingerprint',\n              '${draft.hostKeyType} ${draft.hostKeyFingerprint}',\n            ),\n          if (selectedSshServerVersion != null)\n            _ReviewRow('Server', selectedSshServerVersion!),\n          const SizedBox(height: 1),\n          const Text(\n            'Passwords and key passphrases are kept only in memory and are never written to the profile.',\n            style: TextStyle(color: _muted),\n          ),\n          _ActionButton(\n            label: connected ? 'Изменить SSH-подключение' : 'Настроить SSH',\n            onTap: _openSshPicker,\n            muted: connected,\n          ),\n        ],\n      ),\n    );\n  }\n\n  Widget _dockerSelectionPanel(SourceType sourceType) {\n",
)

# Dashboard wiring.
replace_once(
    path,
    "    required this.locale,\n    required this.onNewProfile,\n",
    "    required this.locale,\n    required this.sshSecrets,\n    required this.onNewProfile,\n",
)
replace_once(
    path,
    "  final String locale;\n  final VoidCallback onNewProfile;\n",
    "  final String locale;\n  final Map<String, SshConnectionSecrets> sshSecrets;\n  final VoidCallback onNewProfile;\n",
)
replace_once(
    path,
    "  final verifyPath = TextEditingController();\n  final dashboardFocus = FocusNode(debugLabel: 'Centra dashboard');\n",
    "  final verifyPath = TextEditingController();\n  final sshPassword = TextEditingController();\n  final sshKeyPassphrase = TextEditingController();\n  final dashboardFocus = FocusNode(debugLabel: 'Centra dashboard');\n",
)
replace_once(
    path,
    "  final verifyPathFocus = FocusNode(debugLabel: 'Manifest path');\n  var showPassword = false;\n  var showVerify = false;\n",
    "  final verifyPathFocus = FocusNode(debugLabel: 'Manifest path');\n  final sshPasswordFocus = FocusNode(debugLabel: 'SSH password');\n  final sshKeyPassphraseFocus = FocusNode(debugLabel: 'SSH key passphrase');\n  var showPassword = false;\n  var showVerify = false;\n  var showSshCredentials = false;\n",
)
replace_once(
    path,
    "    verifyPath.dispose();\n    dashboardFocus.dispose();\n",
    "    verifyPath.dispose();\n    sshPassword.dispose();\n    sshKeyPassphrase.dispose();\n    dashboardFocus.dispose();\n",
)
replace_once(
    path,
    "    verifyPathFocus.dispose();\n    super.dispose();\n",
    "    verifyPathFocus.dispose();\n    sshPasswordFocus.dispose();\n    sshKeyPassphraseFocus.dispose();\n    super.dispose();\n",
)
replace_once(
    path,
    "    if (passwordFocus.hasPrimaryFocus || verifyPathFocus.hasPrimaryFocus) {\n",
    "    if (passwordFocus.hasPrimaryFocus ||\n        verifyPathFocus.hasPrimaryFocus ||\n        sshPasswordFocus.hasPrimaryFocus ||\n        sshKeyPassphraseFocus.hasPrimaryFocus) {\n",
)
replace_once(
    path,
    "  Future<void> _startScan() async {\n    if (running) return;\n",
    "  Future<void> _startScan() async {\n    if (running) return;\n    if (profile.source.type == SourceType.ssh &&\n        profile.source.sshAuthMethod.usesPassword &&\n        !(widget.sshSecrets[profile.id]?.hasPassword ?? false)) {\n      setState(() => showSshCredentials = true);\n      return;\n    }\n",
)
replace_once(
    path,
    "      final result = await IntegrityScanner().scan(\n        profile,\n        onProgress: (value) {\n",
    "      final result = await IntegrityScanner().scan(\n        profile,\n        sshSecrets: widget.sshSecrets[profile.id],\n        onProgress: (value) {\n",
)
replace_once(
    path,
    "    } on Object catch (error) {\n      if (mounted) {\n        setState(() {\n          status = 'failed';\n          message = error.toString();\n        });\n      }\n",
    "    } on Object catch (error) {\n      if (mounted) {\n        final text = error.toString();\n        setState(() {\n          status = 'failed';\n          message = text;\n          if (profile.source.type == SourceType.ssh &&\n              (text.contains('password is required') ||\n                  text.contains('passphrase is required'))) {\n            showSshCredentials = true;\n          }\n        });\n      }\n",
)
replace_once(
    path,
    "       final current = (await IntegrityScanner().scan(\n         profile,\n         onProgress: (value) {\n",
    "       final current = (await IntegrityScanner().scan(\n         profile,\n         sshSecrets: widget.sshSecrets[profile.id],\n         onProgress: (value) {\n",
)

# The previous replacement can miss formatting differences; handle current exact text.
text = Path(path).read_text(encoding='utf-8')
text = text.replace(
    "      final current = (await IntegrityScanner().scan(\n        profile,\n        onProgress: (value) {\n",
    "      final current = (await IntegrityScanner().scan(\n        profile,\n        sshSecrets: widget.sshSecrets[profile.id],\n        onProgress: (value) {\n",
    1,
)
Path(path).write_text(text, encoding='utf-8')

replace_once(
    path,
    "  @override\n  Widget build(BuildContext context) {\n    return Focus(\n      focusNode: dashboardFocus,\n",
    "  void _saveSshCredentials() {\n    widget.sshSecrets[profile.id] = SshConnectionSecrets(\n      password: sshPassword.text.isEmpty ? null : sshPassword.text,\n      keyPassphrase:\n          sshKeyPassphrase.text.isEmpty ? null : sshKeyPassphrase.text,\n    );\n    setState(() => showSshCredentials = false);\n    _startScan();\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    return Focus(\n      focusNode: dashboardFocus,\n",
)
replace_once(
    path,
    "            _ReviewRow(strings('rootPath'), profile.source.root),\n",
    "            _ReviewRow(strings('rootPath'), profile.source.root),\n            if (profile.source.type == SourceType.ssh) ...<Widget>[\n              _ReviewRow(\n                strings('host'),\n                '${profile.source.user}@${profile.source.host}:${profile.source.port}',\n              ),\n              _ReviewRow('SSH auth', profile.source.sshAuthMethod.wireName),\n              _ReviewRow(\n                'Host fingerprint',\n                '${profile.source.hostKeyType ?? ''} ${profile.source.hostKeyFingerprint ?? ''}',\n              ),\n            ],\n",
)
replace_once(
    path,
    "            if (showPassword) ...<Widget>[\n",
    "            if (showSshCredentials) ...<Widget>[\n              const SizedBox(height: 1),\n              const _Notice(\n                'SSH secrets are used only for this application session and are never saved.',\n                _accent,\n              ),\n              if (profile.source.sshAuthMethod.usesPassword) ...<Widget>[\n                const Text('SSH password', style: TextStyle(color: _muted)),\n                GestureDetector(\n                  behavior: HitTestBehavior.opaque,\n                  onTap: sshPasswordFocus.requestFocus,\n                  child: TextField(\n                    controller: sshPassword,\n                    focusNode: sshPasswordFocus,\n                    autofocus: true,\n                    obscureText: true,\n                    width: 50,\n                    placeholder: 'Required for this connection',\n                    decoration: InputDecoration(\n                      fillColor: _surfaceStrong,\n                      border: BoxBorder.all(\n                        color: const Color(0x394453),\n                        style: BoxBorderStyle.rounded,\n                      ),\n                      focusedBorder: BoxBorder.all(\n                        color: _accent,\n                        style: BoxBorderStyle.rounded,\n                      ),\n                    ),\n                  ),\n                ),\n              ],\n              if (profile.source.sshAuthMethod.usesPrivateKey) ...<Widget>[\n                const Text(\n                  'SSH key passphrase (optional)',\n                  style: TextStyle(color: _muted),\n                ),\n                GestureDetector(\n                  behavior: HitTestBehavior.opaque,\n                  onTap: sshKeyPassphraseFocus.requestFocus,\n                  child: TextField(\n                    controller: sshKeyPassphrase,\n                    focusNode: sshKeyPassphraseFocus,\n                    obscureText: true,\n                    width: 50,\n                    placeholder: 'Only for encrypted private keys',\n                    decoration: InputDecoration(\n                      fillColor: _surfaceStrong,\n                      border: BoxBorder.all(\n                        color: const Color(0x394453),\n                        style: BoxBorderStyle.rounded,\n                      ),\n                      focusedBorder: BoxBorder.all(\n                        color: _accent,\n                        style: BoxBorderStyle.rounded,\n                      ),\n                    ),\n                    onSubmitted: (_) => _saveSshCredentials(),\n                  ),\n                ),\n              ],\n              Row(\n                children: <Widget>[\n                  _ActionButton(\n                    label: strings('cancel'),\n                    onTap: () => setState(() => showSshCredentials = false),\n                    muted: true,\n                  ),\n                  const SizedBox(width: 1),\n                  _ActionButton(\n                    label: 'Подключиться и сканировать',\n                    onTap: _saveSshCredentials,\n                  ),\n                ],\n              ),\n            ],\n            if (showPassword) ...<Widget>[\n",
)
