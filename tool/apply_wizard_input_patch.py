from pathlib import Path

path = Path('lib/src/tui/centra_app.dart')
text = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Expected exactly one match, found {count}: {old[:80]!r}')
    text = text.replace(old, new, 1)


replace_once(
    "import '../i18n/messages.dart';\nimport 'wizard_state.dart';",
    "import '../i18n/messages.dart';\nimport 'folder_picker.dart';\nimport 'wizard_state.dart';",
)

replace_once(
    """  final outputDirectory = TextEditingController();
  final exclusionPattern = TextEditingController();

  CentraStrings get strings =>
      CentraStrings(draft.locale ?? widget.initialLocale ?? 'en');
""",
    """  final outputDirectory = TextEditingController();
  final exclusionPattern = TextEditingController();

  final wizardFocus = FocusNode(debugLabel: 'Centra wizard');
  final profileNameFocus = FocusNode(debugLabel: 'Profile name');
  final profileIdFocus = FocusNode(debugLabel: 'Profile ID');
  final rootFocus = FocusNode(debugLabel: 'Source root');
  final hostFocus = FocusNode(debugLabel: 'SSH host');
  final userFocus = FocusNode(debugLabel: 'SSH user');
  final portFocus = FocusNode(debugLabel: 'SSH port');
  final identityFileFocus = FocusNode(debugLabel: 'SSH identity file');
  final containerFocus = FocusNode(debugLabel: 'Docker container');
  final imageFocus = FocusNode(debugLabel: 'Docker image');
  final serviceFocus = FocusNode(debugLabel: 'Compose service');
  final composeFileFocus = FocusNode(debugLabel: 'Compose file');
  final dockerContextFocus = FocusNode(debugLabel: 'Docker context');
  final outputDirectoryFocus = FocusNode(debugLabel: 'Output directory');
  final exclusionPatternFocus = FocusNode(debugLabel: 'Exclusion pattern');

  TextEditingController? folderPickerController;
  FocusNode? folderPickerReturnFocus;

  String get locale => draft.locale ?? widget.initialLocale ?? 'en';
  CentraStrings get strings => CentraStrings(locale);
  FolderPickerStrings get folderStrings =>
      FolderPickerStrings.forLocale(locale);

  List<FocusNode> get _textFieldFocusNodes => <FocusNode>[
        profileNameFocus,
        profileIdFocus,
        rootFocus,
        hostFocus,
        userFocus,
        portFocus,
        identityFileFocus,
        containerFocus,
        imageFocus,
        serviceFocus,
        composeFileFocus,
        dockerContextFocus,
        outputDirectoryFocus,
        exclusionPatternFocus,
      ];
""",
)

replace_once(
    """    ]) {
      controller.dispose();
    }
    super.dispose();
""",
    """    ]) {
      controller.dispose();
    }
    for (final focusNode in <FocusNode>[
      wizardFocus,
      ..._textFieldFocusNodes,
    ]) {
      focusNode.dispose();
    }
    super.dispose();
""",
)

replace_once(
    """  List<Object> get _itemsForStep => switch (step) {
""",
    """  void _openFolderPicker(
    TextEditingController controller,
    FocusNode returnFocus,
  ) {
    setState(() {
      error = null;
      folderPickerController = controller;
      folderPickerReturnFocus = returnFocus;
    });
  }

  void _closeFolderPicker() {
    final returnFocus = folderPickerReturnFocus;
    setState(() {
      folderPickerController = null;
      folderPickerReturnFocus = null;
    });
    returnFocus?.requestFocus();
  }

  void _selectFolder(String path) {
    final controller = folderPickerController;
    final returnFocus = folderPickerReturnFocus;
    if (controller != null) controller.text = path;
    _syncDraft();
    setState(() {
      error = null;
      folderPickerController = null;
      folderPickerReturnFocus = null;
    });
    returnFocus?.requestFocus();
  }

  bool _stepHasTextField(WizardStep candidate) =>
      candidate == WizardStep.details ||
      candidate == WizardStep.exclusions ||
      candidate == WizardStep.output;

  List<Object> get _itemsForStep => switch (step) {
""",
)

replace_once(
    """  bool _handleKey(KeyboardEvent event) {
    if (event.matches(LogicalKey.keyC, ctrl: true) ||
        event.matches(LogicalKey.keyQ, ctrl: true)) {
      widget.onCancel();
      return true;
    }
    if (event.logicalKey == LogicalKey.escape) {
      _back();
      return true;
    }
""",
    """  bool _handleKey(KeyboardEvent event) {
    if (folderPickerController != null) return false;
    if (event.matches(LogicalKey.keyC, ctrl: true) ||
        event.matches(LogicalKey.keyQ, ctrl: true)) {
      widget.onCancel();
      return true;
    }
    if (_textFieldFocusNodes.any((node) => node.hasPrimaryFocus)) {
      if (event.logicalKey == LogicalKey.escape) {
        FocusManager.instance.primaryFocus?.unfocus();
        wizardFocus.requestFocus();
        return true;
      }
      return false;
    }
    if (event.logicalKey == LogicalKey.escape) {
      _back();
      return true;
    }
""",
)

replace_once(
    """    setState(() {
      step = WizardStep.values[step.index + 1];
      cursor = 0;
      error = null;
    });
""",
    """    final nextStep = WizardStep.values[step.index + 1];
    setState(() {
      step = nextStep;
      cursor = 0;
      error = null;
    });
    if (!_stepHasTextField(nextStep)) wizardFocus.requestFocus();
""",
)

replace_once(
    """    setState(() {
      step = WizardStep.values[step.index - 1];
      cursor = 0;
      error = null;
    });
""",
    """    final previousStep = WizardStep.values[step.index - 1];
    setState(() {
      step = previousStep;
      cursor = 0;
      error = null;
    });
    if (!_stepHasTextField(previousStep)) wizardFocus.requestFocus();
""",
)

replace_once(
    """                setState(() {
                  step = candidate;
                  cursor = 0;
                  error = null;
                });
""",
    """                setState(() {
                  step = candidate;
                  cursor = 0;
                  error = null;
                });
                if (!_stepHasTextField(candidate)) {
                  wizardFocus.requestFocus();
                }
""",
)

old_build = """  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Container(
        color: _background,
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(
              title: 'CENTRA',
              subtitle: strings('tagline'),
              trailing: '${step.index + 1}/${WizardStep.values.length}',
            ),
            const SizedBox(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(width: 25, child: _stepRail()),
                  const SizedBox(width: 1),
                  Expanded(child: _content()),
                ],
              ),
            ),
            const SizedBox(height: 1),
            _Footer(
              left: error == null ? strings('keyboardHelp') : '⚠ $error',
              right: saving
                  ? '${strings('saveProfile')}…'
                  : 'Ctrl+Q ${strings('quit')}',
              warning: error != null,
            ),
          ],
        ),
      ),
    );
  }
"""
new_build = """  @override
  Widget build(BuildContext context) {
    final screen = Focus(
      focusNode: wizardFocus,
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: Container(
        color: _background,
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(
              title: 'CENTRA',
              subtitle: strings('tagline'),
              trailing: '${step.index + 1}/${WizardStep.values.length}',
            ),
            const SizedBox(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(width: 25, child: _stepRail()),
                  const SizedBox(width: 1),
                  Expanded(child: _content()),
                ],
              ),
            ),
            const SizedBox(height: 1),
            _Footer(
              left: error == null ? strings('keyboardHelp') : '⚠ $error',
              right: saving
                  ? '${strings('saveProfile')}…'
                  : 'Ctrl+Q ${strings('quit')}',
              warning: error != null,
            ),
          ],
        ),
      ),
    );

    final pickerController = folderPickerController;
    if (pickerController == null) return screen;

    return Stack(
      children: <Widget>[
        screen,
        ModalBarrier(
          color: const Color(0x000000).withAlpha(196),
          obscure: false,
          onDismiss: _closeFolderPicker,
        ),
        Center(
          child: FolderPicker(
            initialPath: pickerController.text,
            locale: locale,
            onSelected: _selectFolder,
            onCancel: _closeFolderPicker,
          ),
        ),
      ],
    );
  }
"""
replace_once(old_build, new_build)

replace_once(
    """    final fields = <Widget>[
      _field(strings('profileName'), profileName, 'Production application'),
      _field(strings('profileId'), profileId, 'production-app'),
      _field(strings('rootPath'), root,
          draft.sourceType == SourceType.local ? '/srv/application' : '/app'),
    ];
""",
    """    final fields = <Widget>[
      _field(
        strings('profileName'),
        profileName,
        profileNameFocus,
        'Production application',
        autofocus: true,
      ),
      _field(strings('profileId'), profileId, profileIdFocus, 'production-app'),
      _field(
        strings('rootPath'),
        root,
        rootFocus,
        draft.sourceType == SourceType.local ? Directory.current.path : '/app',
        trailing: draft.sourceType == SourceType.local
            ? _ActionButton(
                label: folderStrings.browse,
                onTap: () => _openFolderPicker(root, rootFocus),
                muted: true,
              )
            : null,
      ),
    ];
""",
)

replacements = {
    "_field(strings('host'), host, 'server.example.com')": "_field(strings('host'), host, hostFocus, 'server.example.com')",
    "_field(strings('user'), user, 'deploy')": "_field(strings('user'), user, userFocus, 'deploy')",
    "_field(strings('port'), port, '22')": "_field(strings('port'), port, portFocus, '22')",
    "_field(strings('identityFile'), identityFile, '~/.ssh/id_ed25519')": "_field(strings('identityFile'), identityFile, identityFileFocus, '~/.ssh/id_ed25519')",
    "_field(strings('container'), container, 'application-1')": "_field(strings('container'), container, containerFocus, 'application-1')",
    "_field(strings('dockerContext'), dockerContext, 'default')": "_field(strings('dockerContext'), dockerContext, dockerContextFocus, 'default')",
    "_field(strings('service'), service, 'api')": "_field(strings('service'), service, serviceFocus, 'api')",
    "_field(strings('composeFile'), composeFile, 'compose.production.yml')": "_field(strings('composeFile'), composeFile, composeFileFocus, 'compose.production.yml')",
}
for old, new in replacements.items():
    count = text.count(old)
    if count == 0:
        raise SystemExit(f'Missing field call: {old}')
    text = text.replace(old, new)

replace_once(
    """          _field(strings('image'), image,
              'registry.example.com/application:1.0.0'),
""",
    """          _field(
            strings('image'),
            image,
            imageFocus,
            'registry.example.com/application:1.0.0',
          ),
""",
)

replace_once(
    """          _field(strings('addPattern'), exclusionPattern, '**/private/**',
              onSubmitted: (_) => _addExclusion()),
""",
    """          _field(
            strings('addPattern'),
            exclusionPattern,
            exclusionPatternFocus,
            '**/private/**',
            autofocus: true,
            onSubmitted: (_) => _addExclusion(),
          ),
""",
)

replace_once(
    """        _field(strings('outputDirectory'), outputDirectory, './centra-output'),
""",
    """        _field(
          strings('outputDirectory'),
          outputDirectory,
          outputDirectoryFocus,
          './centra-output',
          autofocus: true,
          trailing: _ActionButton(
            label: folderStrings.browse,
            onTap: () =>
                _openFolderPicker(outputDirectory, outputDirectoryFocus),
            muted: true,
          ),
        ),
""",
)

old_field = """  Widget _field(
    String label,
    TextEditingController controller,
    String placeholder, {
    ValueChanged<String>? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(label, style: const TextStyle(color: _muted)),
          TextField(
            controller: controller,
            width: 68,
            placeholder: placeholder,
            style: const TextStyle(color: _text),
            placeholderStyle:
                const TextStyle(color: _muted, fontStyle: FontStyle.italic),
            decoration: InputDecoration(
              fillColor: _surfaceStrong,
              border: BoxBorder.all(
                  color: const Color(0x394453), style: BoxBorderStyle.rounded),
              focusedBorder:
                  BoxBorder.all(color: _accent, style: BoxBorderStyle.rounded),
            ),
            onChanged: (_) => _syncDraft(),
            onSubmitted: onSubmitted ?? (_) => _next(),
          ),
        ],
      ),
    );
  }
"""
new_field = """  Widget _field(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    String placeholder, {
    ValueChanged<String>? onSubmitted,
    Widget? trailing,
    bool autofocus = false,
  }) {
    final input = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focusNode.requestFocus,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        width: trailing == null ? 68 : null,
        placeholder: placeholder,
        style: const TextStyle(color: _text),
        placeholderStyle:
            const TextStyle(color: _muted, fontStyle: FontStyle.italic),
        decoration: InputDecoration(
          fillColor: _surfaceStrong,
          border: BoxBorder.all(
            color: const Color(0x394453),
            style: BoxBorderStyle.rounded,
          ),
          focusedBorder:
              BoxBorder.all(color: _accent, style: BoxBorderStyle.rounded),
        ),
        onChanged: (_) => _syncDraft(),
        onSubmitted: onSubmitted ?? (_) => _next(),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(label, style: const TextStyle(color: _muted)),
          if (trailing == null)
            input
          else
            Row(
              children: <Widget>[
                Expanded(child: input),
                const SizedBox(width: 1),
                trailing,
              ],
            ),
        ],
      ),
    );
  }
"""
replace_once(old_field, new_field)

replace_once(
    """  final password = TextEditingController();
  final verifyPath = TextEditingController();
  var showPassword = false;
""",
    """  final password = TextEditingController();
  final verifyPath = TextEditingController();
  final dashboardFocus = FocusNode(debugLabel: 'Centra dashboard');
  final passwordFocus = FocusNode(debugLabel: 'ZIP password');
  final verifyPathFocus = FocusNode(debugLabel: 'Manifest path');
  var showPassword = false;
""",
)

replace_once(
    """  void dispose() {
    password.dispose();
    verifyPath.dispose();
    super.dispose();
  }

  bool _handleKey(KeyboardEvent event) {
    if (event.matches(LogicalKey.keyQ, ctrl: true) ||
        event.logicalKey == LogicalKey.keyQ) {
      shutdownApp();
      return true;
    }
""",
    """  void dispose() {
    password.dispose();
    verifyPath.dispose();
    dashboardFocus.dispose();
    passwordFocus.dispose();
    verifyPathFocus.dispose();
    super.dispose();
  }

  bool _handleKey(KeyboardEvent event) {
    if (event.matches(LogicalKey.keyQ, ctrl: true)) {
      shutdownApp();
      return true;
    }
    if (passwordFocus.hasPrimaryFocus || verifyPathFocus.hasPrimaryFocus) {
      return false;
    }
    if (event.logicalKey == LogicalKey.keyQ) {
      shutdownApp();
      return true;
    }
""",
)

replace_once(
    """    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
""",
    """    return Focus(
      focusNode: dashboardFocus,
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: _handleKey,
""",
)

replace_once(
    """              TextField(
                controller: password,
                obscureText: true,
""",
    """              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: passwordFocus.requestFocus,
                child: TextField(
                  controller: password,
                  focusNode: passwordFocus,
                  autofocus: true,
                  obscureText: true,
""",
)
replace_once(
    """                onSubmitted: (_) => _startScan(),
              ),
              _ActionButton(label: strings('scanNow'), onTap: _startScan),
""",
    """                  onSubmitted: (_) => _startScan(),
                ),
              ),
              _ActionButton(label: strings('scanNow'), onTap: _startScan),
""",
)

replace_once(
    """              TextField(
                controller: verifyPath,
                width: 68,
""",
    """              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: verifyPathFocus.requestFocus,
                child: TextField(
                  controller: verifyPath,
                  focusNode: verifyPathFocus,
                  autofocus: true,
                  width: 68,
""",
)
replace_once(
    """                onSubmitted: (_) => _verify(),
              ),
              _ActionButton(label: strings('verify'), onTap: _verify),
""",
    """                  onSubmitted: (_) => _verify(),
                ),
              ),
              _ActionButton(label: strings('verify'), onTap: _verify),
""",
)

path.write_text(text, encoding='utf-8')
print('Wizard focus and folder picker integration applied.')
