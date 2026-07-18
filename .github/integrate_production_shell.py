from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Pattern not found: {label}')
    return text.replace(old, new, 1)


path = Path('lib/src/tui/centra_app.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    "import 'folder_picker.dart';\nimport 'ssh_source_picker.dart';\n",
    "import 'folder_picker.dart';\nimport 'production_dashboard.dart';\nimport 'settings_panel.dart';\nimport 'ssh_connection_library.dart';\nimport 'ssh_source_picker.dart';\n",
    'production TUI imports',
)
text = replace_once(
    text,
    '''  late bool showWizard;
  final sshSecrets = <String, SshConnectionSecrets>{};
''',
    '''  late bool showWizard;
  var showSettings = false;
  final sshSecrets = <String, SshConnectionSecrets>{};
''',
    'shell settings state',
)
text = replace_once(
    text,
    '''    settings = CentraSettings(
      locale: profile.locale,
      theme: settings.theme,
      confirmDestructiveActions: settings.confirmDestructiveActions,
    );
''',
    '''    settings = settings.copyWith(
      locale: profile.locale,
      onboardingCompleted: true,
      lastProfileId: profile.id,
    );
''',
    'persistent settings update',
)
insert_before_build = '''
  Future<void> _settingsSaved(CentraSettings updated) async {
    await widget.settingsStore.save(updated);
    if (!mounted) return;
    setState(() {
      settings = updated;
      showSettings = false;
    });
  }

  void _profilesChanged(List<CentraProfile> updated) {
    if (!mounted) return;
    setState(() => profiles = List<CentraProfile>.from(updated));
  }

'''
text = replace_once(
    text,
    '''  @override
  Widget build(BuildContext context) {
''',
    insert_before_build + '''  @override
  Widget build(BuildContext context) {
''',
    'shell callbacks',
)
text = replace_once(
    text,
    '''    if (showWizard) {
      return _WizardScreen(
        initialLocale: profiles.isEmpty ? null : settings.locale,
        onSaved: _profileSaved,
''',
    '''    if (showSettings) {
      return Center(
        child: CentraSettingsPanel(
          settings: settings,
          onSaved: _settingsSaved,
          onCancel: () => setState(() => showSettings = false),
        ),
      );
    }
    if (showWizard) {
      return _WizardScreen(
        initialLocale: settings.locale,
        skipLanguageSelection: settings.onboardingCompleted,
        onSaved: _profileSaved,
''',
    'settings and wizard routing',
)
old_dashboard = '''    return _Dashboard(
      profiles: profiles,
      locale: settings.locale,
      sshSecrets: sshSecrets,
      onNewProfile: () => setState(() => showWizard = true),
    );
'''
new_dashboard = '''    return ProductionDashboard(
      profiles: profiles,
      locale: settings.locale,
      sshSecrets: sshSecrets,
      profileStore: widget.profileStore,
      onProfilesChanged: _profilesChanged,
      onNewProfile: () => setState(() => showWizard = true),
      onSettings: () => setState(() => showSettings = true),
    );
'''
text = replace_once(text, old_dashboard, new_dashboard, 'production dashboard')
text = replace_once(
    text,
    '''    required this.initialLocale,
    required this.onSaved,
''',
    '''    required this.initialLocale,
    required this.skipLanguageSelection,
    required this.onSaved,
''',
    'wizard skip language constructor',
)
text = replace_once(
    text,
    '''  final String? initialLocale;
  final Future<void> Function(
''',
    '''  final String? initialLocale;
  final bool skipLanguageSelection;
  final Future<void> Function(
''',
    'wizard skip language field',
)
text = replace_once(
    text,
    '''  final draft = WizardDraft();
  var step = WizardStep.language;
''',
    '''  final draft = WizardDraft();
  late WizardStep step;
''',
    'wizard late step',
)
init_anchor = '''  String get locale => draft.locale ?? widget.initialLocale ?? 'en';
'''
init_block = '''  @override
  void initState() {
    super.initState();
    draft.locale = widget.initialLocale;
    step = widget.skipLanguageSelection
        ? WizardStep.source
        : WizardStep.language;
  }

'''
text = replace_once(text, init_anchor, init_block + init_anchor, 'wizard initial state')
text = replace_once(
    text,
    '''    if (step == WizardStep.language) {
      widget.onCancel();
      return;
    }
''',
    '''    if (step == WizardStep.language ||
        (widget.skipLanguageSelection && step == WizardStep.source)) {
      widget.onCancel();
      return;
    }
''',
    'wizard back from skipped language',
)
old_picker = '''            child: SshSourcePicker(
              locale: locale,
              initialHost: host.text.trim(),
              initialPort: int.tryParse(port.text.trim()) ?? 22,
              initialUser: user.text.trim(),
              initialPath: root.text.trim().isEmpty ? '/' : root.text.trim(),
              initialAuthMethod: draft.sshAuthMethod,
              initialIdentityFile: identityFile.text.trim().isEmpty
                  ? null
                  : identityFile.text.trim(),
              initialFingerprint: draft.hostKeyFingerprint.trim().isEmpty
                  ? null
                  : draft.hostKeyFingerprint.trim(),
              initialConnectTimeoutSeconds: draft.connectTimeoutSeconds,
              initialKeepAliveSeconds: draft.keepAliveSeconds,
              initialSecrets:
                  sshConnectionSecrets ?? const SshConnectionSecrets(),
              onSelected: _selectSshSource,
              onCancel: _closeSshPicker,
            ),
'''
new_picker = '''            child: SshConnectionLibrary(
              locale: locale,
              initialHost: host.text.trim(),
              initialPort: int.tryParse(port.text.trim()) ?? 22,
              initialUser: user.text.trim(),
              initialPath: root.text.trim().isEmpty ? '/' : root.text.trim(),
              initialAuthMethod: draft.sshAuthMethod,
              initialIdentityFile: identityFile.text.trim().isEmpty
                  ? null
                  : identityFile.text.trim(),
              initialFingerprint: draft.hostKeyFingerprint.trim().isEmpty
                  ? null
                  : draft.hostKeyFingerprint.trim(),
              initialConnectTimeoutSeconds: draft.connectTimeoutSeconds,
              initialKeepAliveSeconds: draft.keepAliveSeconds,
              initialSecrets:
                  sshConnectionSecrets ?? const SshConnectionSecrets(),
              onSelected: _selectSshSource,
              onCancel: _closeSshPicker,
            ),
'''
text = replace_once(text, old_picker, new_picker, 'SSH connection library overlay')
text = replace_once(
    text,
    '''      ..connectTimeoutSeconds = selection.connectTimeoutSeconds
      ..keepAliveSeconds = selection.keepAliveSeconds;
''',
    '''      ..connectTimeoutSeconds = selection.connectTimeoutSeconds
      ..keepAliveSeconds = selection.keepAliveSeconds
      ..sshConnectionId = selection.connectionId ?? ''
      ..sshConnectionName = selection.connectionName ?? '';
''',
    'wizard saved SSH selection',
)
path.write_text(text, encoding='utf-8')
