import 'dart:io';

import 'package:cinder/cinder.dart';

import '../core/algorithm_registry.dart';
import '../core/docker_browser.dart';
import '../core/manifest.dart';
import '../core/path_policy.dart';
import '../core/profile.dart';
import '../core/scanner.dart';
import '../core/services.dart';
import '../core/storage.dart';
import '../core/ssh_connection.dart';
import '../i18n/messages.dart';
import 'docker_source_picker.dart';
import 'folder_picker.dart';
import 'production_dashboard.dart';
import 'settings_panel.dart';
import 'ssh_connection_library.dart';
import 'ssh_source_picker.dart';
import 'wizard_state.dart';

const _accent = Color(0x64D8CB);
const _background = Color(0x0D1117);
const _surface = Color(0x151B23);
const _surfaceStrong = Color(0x1D2632);
const _muted = Color(0x7D8A99);
const _text = Color(0xE6EDF3);
const _warning = Color(0xE3B341);
const _danger = Color(0xF47067);
const _success = Color(0x56D364);

final _centraTheme = TuiThemeData.dark.copyWith(
  background: _background,
  onBackground: _text,
  surface: _surface,
  onSurface: _text,
  primary: _accent,
  onPrimary: _background,
  secondary: const Color(0x58A6FF),
  outline: const Color(0x394453),
  outlineVariant: const Color(0x27313D),
  warning: _warning,
  error: _danger,
  success: _success,
);

Future<void> runCentraTui({
  required CentraPaths paths,
  bool forceWizard = false,
}) async {
  await paths.ensure();
  final settingsStore = SettingsStore(paths);
  final profileStore = ProfileStore(paths);
  final settings = await settingsStore.load();
  final profiles = await profileStore.list();
  await runApp(
    CinderApp(
      title: 'Centra',
      iconName: 'Centra',
      theme: _centraTheme,
      child: _CentraShell(
        paths: paths,
        settingsStore: settingsStore,
        profileStore: profileStore,
        initialSettings: settings,
        initialProfiles: profiles,
        forceWizard: forceWizard,
      ),
    ),
  );
}

class _CentraShell extends StatefulWidget {
  const _CentraShell({
    required this.paths,
    required this.settingsStore,
    required this.profileStore,
    required this.initialSettings,
    required this.initialProfiles,
    required this.forceWizard,
  });

  final CentraPaths paths;
  final SettingsStore settingsStore;
  final ProfileStore profileStore;
  final CentraSettings initialSettings;
  final List<CentraProfile> initialProfiles;
  final bool forceWizard;

  @override
  State<_CentraShell> createState() => _CentraShellState();
}

class _CentraShellState extends State<_CentraShell> {
  late CentraSettings settings;
  late List<CentraProfile> profiles;
  late bool showWizard;
  var showSettings = false;
  final sshSecrets = <String, SshConnectionSecrets>{};

  @override
  void initState() {
    super.initState();
    settings = widget.initialSettings;
    profiles = List<CentraProfile>.from(widget.initialProfiles);
    showWizard = widget.forceWizard || profiles.isEmpty;
  }

  Future<void> _profileSaved(
    CentraProfile profile,
    SshConnectionSecrets? secrets,
  ) async {
    await widget.profileStore.save(profile);
    if (secrets != null) sshSecrets[profile.id] = secrets;
    settings = settings.copyWith(
      locale: profile.locale,
      onboardingCompleted: true,
      lastProfileId: profile.id,
    );
    await widget.settingsStore.save(settings);
    final refreshed = await widget.profileStore.list();
    if (!mounted) return;
    setState(() {
      profiles = refreshed;
      showWizard = false;
    });
  }

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

  @override
  Widget build(BuildContext context) {
    if (showSettings) {
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
        skipLanguageSelection:
            settings.onboardingCompleted || profiles.isNotEmpty,
        onSaved: _profileSaved,
        onCancel: () {
          if (profiles.isEmpty) {
            shutdownApp();
          } else {
            setState(() => showWizard = false);
          }
        },
      );
    }
    return ProductionDashboard(
      profiles: profiles,
      locale: settings.locale,
      sshSecrets: sshSecrets,
      profileStore: widget.profileStore,
      onProfilesChanged: _profilesChanged,
      onNewProfile: () => setState(() => showWizard = true),
      onSettings: () => setState(() => showSettings = true),
    );
  }
}

class _WizardScreen extends StatefulWidget {
  const _WizardScreen({
    required this.initialLocale,
    required this.skipLanguageSelection,
    required this.onSaved,
    required this.onCancel,
  });

  final String? initialLocale;
  final bool skipLanguageSelection;
  final Future<void> Function(
    CentraProfile profile,
    SshConnectionSecrets? secrets,
  ) onSaved;
  final VoidCallback onCancel;

  @override
  State<_WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<_WizardScreen> {
  final draft = WizardDraft();
  late WizardStep step;
  var cursor = 0;
  String? error;
  var saving = false;
  List<String> exclusionSuggestions = const <String>[];

  final profileName = TextEditingController();
  final profileId = TextEditingController();
  final root = TextEditingController();
  final host = TextEditingController();
  final user = TextEditingController();
  final port = TextEditingController(text: '22');
  final identityFile = TextEditingController();
  final container = TextEditingController();
  final image = TextEditingController();
  final service = TextEditingController();
  final composeFile = TextEditingController();
  final dockerContext = TextEditingController();
  final outputDirectory = TextEditingController();
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
  SourceType? dockerPickerSourceType;
  String? selectedDockerResourceTitle;
  var sshPickerOpen = false;
  SshConnectionSecrets? sshConnectionSecrets;
  String? selectedSshServerVersion;

  @override
  void initState() {
    super.initState();
    draft.locale = widget.initialLocale;
    step =
        widget.skipLanguageSelection ? WizardStep.source : WizardStep.language;
  }

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

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      profileName,
      profileId,
      root,
      host,
      user,
      port,
      identityFile,
      container,
      image,
      service,
      composeFile,
      dockerContext,
      outputDirectory,
      exclusionPattern,
    ]) {
      controller.dispose();
    }
    for (final focusNode in <FocusNode>[wizardFocus, ..._textFieldFocusNodes]) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _syncDraft() {
    draft
      ..profileName = profileName.text
      ..profileId = profileId.text
      ..root = root.text
      ..host = host.text
      ..user = user.text
      ..port = port.text
      ..identityFile = identityFile.text
      ..container = container.text
      ..image = image.text
      ..service = service.text
      ..composeFile = composeFile.text
      ..dockerContext = dockerContext.text
      ..outputDirectory = outputDirectory.text;
  }

  void _openFolderPicker(
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

  String? _selectedDockerReference(SourceType sourceType) =>
      switch (sourceType) {
        SourceType.dockerContainer => container.text.trim(),
        SourceType.dockerImage => image.text.trim(),
        SourceType.dockerCompose => service.text.trim(),
        SourceType.local || SourceType.ssh => null,
      };

  void _openDockerPicker() {
    _syncDraft();
    final sourceType = draft.sourceType;
    if (sourceType != SourceType.dockerContainer &&
        sourceType != SourceType.dockerImage &&
        sourceType != SourceType.dockerCompose) {
      return;
    }
    setState(() {
      error = null;
      dockerPickerSourceType = sourceType;
    });
  }

  void _closeDockerPicker() {
    setState(() => dockerPickerSourceType = null);
    wizardFocus.requestFocus();
  }

  void _selectDockerSource(DockerSourceSelection selection) {
    root.text = selection.path;
    switch (selection.sourceType) {
      case SourceType.dockerContainer:
        container.text = selection.resource.reference;
        break;
      case SourceType.dockerImage:
        image.text = selection.resource.reference;
        break;
      case SourceType.dockerCompose:
        service.text = selection.resource.reference;
        break;
      case SourceType.local:
      case SourceType.ssh:
        return;
    }
    selectedDockerResourceTitle = selection.resource.title;
    _syncDraft();
    setState(() {
      error = null;
      dockerPickerSourceType = null;
    });
    wizardFocus.requestFocus();
  }

  void _openSshPicker() {
    _syncDraft();
    setState(() {
      error = null;
      sshPickerOpen = true;
    });
  }

  void _closeSshPicker() {
    setState(() => sshPickerOpen = false);
    wizardFocus.requestFocus();
  }

  void _selectSshSource(SshSourceSelection selection) {
    host.text = selection.host;
    port.text = selection.port.toString();
    user.text = selection.user;
    root.text = selection.path;
    identityFile.text = selection.identityFile ?? '';
    draft
      ..sshAuthMethod = selection.authMethod
      ..sshHostKeyPolicy = SshHostKeyPolicy.pinned
      ..hostKeyType = selection.hostKeyType
      ..hostKeyFingerprint = selection.hostKeyFingerprint
      ..connectTimeoutSeconds = selection.connectTimeoutSeconds
      ..keepAliveSeconds = selection.keepAliveSeconds
      ..sshConnectionId = selection.connectionId ?? ''
      ..sshConnectionName = selection.connectionName ?? '';
    sshConnectionSecrets = selection.secrets;
    selectedSshServerVersion = selection.serverVersion;
    _syncDraft();
    setState(() {
      error = null;
      sshPickerOpen = false;
    });
    wizardFocus.requestFocus();
  }

  bool _stepHasTextField(WizardStep candidate) =>
      candidate == WizardStep.details ||
      candidate == WizardStep.exclusions ||
      candidate == WizardStep.output;

  List<Object> get _itemsForStep => switch (step) {
        WizardStep.language => CentraStrings.locales,
        WizardStep.source => SourceType.values,
        WizardStep.algorithms => AlgorithmRegistry.builtIns,
        WizardStep.exclusions => exclusionSuggestions,
        WizardStep.output => const <String>[
            'json',
            'text',
            'zip',
            'report',
            'zip-password',
          ],
        _ => const <Object>[],
      };

  bool _handleKey(KeyboardEvent event) {
    if (folderPickerController != null ||
        dockerPickerSourceType != null ||
        sshPickerOpen) {
      return false;
    }
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
    final items = _itemsForStep;
    if (items.isNotEmpty && event.logicalKey == LogicalKey.arrowUp) {
      setState(() => cursor = cursor <= 0 ? items.length - 1 : cursor - 1);
      return true;
    }
    if (items.isNotEmpty && event.logicalKey == LogicalKey.arrowDown) {
      setState(() => cursor = (cursor + 1) % items.length);
      return true;
    }
    if (items.isNotEmpty && event.logicalKey == LogicalKey.space) {
      _activate(cursor, continueAfter: false);
      return true;
    }
    if (event.logicalKey == LogicalKey.enter) {
      if (items.isNotEmpty) {
        _activate(
          cursor,
          continueAfter:
              step == WizardStep.language || step == WizardStep.source,
        );
      } else {
        _next();
      }
      return true;
    }
    return false;
  }

  void _activate(int index, {required bool continueAfter}) {
    final items = _itemsForStep;
    if (index < 0 || index >= items.length) return;
    setState(() {
      error = null;
      cursor = index;
      switch (step) {
        case WizardStep.language:
          draft.locale = (items[index] as LocaleOption).code;
          break;
        case WizardStep.source:
          final nextSource = items[index] as SourceType;
          if (draft.sourceType != nextSource) {
            root.clear();
            container.clear();
            image.clear();
            service.clear();
            selectedDockerResourceTitle = null;
            sshConnectionSecrets = null;
            selectedSshServerVersion = null;
            draft
              ..hostKeyType = ''
              ..hostKeyFingerprint = '';
          }
          draft.sourceType = nextSource;
          break;
        case WizardStep.algorithms:
          final id = (items[index] as HashAlgorithmDescriptor).id;
          draft.algorithmIds.contains(id)
              ? draft.algorithmIds.remove(id)
              : draft.algorithmIds.add(id);
          break;
        case WizardStep.exclusions:
          final pattern = items[index] as String;
          draft.excludePatterns.contains(pattern)
              ? draft.excludePatterns.remove(pattern)
              : draft.excludePatterns.add(pattern);
          break;
        case WizardStep.output:
          switch (items[index] as String) {
            case 'json':
              draft.canonicalJson = !draft.canonicalJson;
              break;
            case 'text':
              draft.compatibilityText = !draft.compatibilityText;
              break;
            case 'zip':
              draft.zipPackage = !draft.zipPackage;
              break;
            case 'report':
              draft.metadataReport = !draft.metadataReport;
              break;
            case 'zip-password':
              draft.requireZipPassword = !draft.requireZipPassword;
              break;
          }
          break;
        case WizardStep.details:
        case WizardStep.review:
          break;
      }
    });
    if (continueAfter) _next();
  }

  Future<void> _prepareExclusions() async {
    _syncDraft();
    final rootNames = <String>{};
    if (draft.sourceType == SourceType.local && root.text.trim().isNotEmpty) {
      final directory = Directory(root.text.trim());
      if (await directory.exists()) {
        await for (final entity in directory.list(followLinks: false)) {
          final segments = entity.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .toList();
          if (segments.isNotEmpty) rootNames.add(segments.last);
        }
      }
    }
    final detection = await ProjectDetector.detect(rootNames);
    draft.projectKind = detection.kind;
    exclusionSuggestions = detection.suggestedExcludes;
  }

  Future<void> _next() async {
    if (saving) return;
    _syncDraft();
    final errors = draft.validateStep(step);
    if (errors.isNotEmpty) {
      setState(() => error = errors.first);
      return;
    }
    if (step == WizardStep.details) await _prepareExclusions();
    if (step == WizardStep.review) {
      setState(() => saving = true);
      try {
        await widget.onSaved(draft.toProfile(), sshConnectionSecrets);
      } on Object catch (exception) {
        if (mounted) setState(() => error = exception.toString());
      } finally {
        if (mounted) setState(() => saving = false);
      }
      return;
    }
    final nextStep = WizardStep.values[step.index + 1];
    setState(() {
      step = nextStep;
      cursor = 0;
      error = null;
    });
    if (!_stepHasTextField(nextStep)) wizardFocus.requestFocus();
  }

  void _back() {
    if (step == WizardStep.language ||
        (widget.skipLanguageSelection && step == WizardStep.source)) {
      widget.onCancel();
      return;
    }
    final previousStep = WizardStep.values[step.index - 1];
    setState(() {
      step = previousStep;
      cursor = 0;
      error = null;
    });
    if (!_stepHasTextField(previousStep)) wizardFocus.requestFocus();
  }

  void _addExclusion() {
    final value = exclusionPattern.text.trim().replaceAll('\\', '/');
    if (value.isEmpty) return;
    setState(() {
      draft.excludePatterns.add(value);
      exclusionPattern.clear();
    });
  }

  @override
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

    if (sshPickerOpen) {
      return Stack(
        children: <Widget>[
          screen,
          ModalBarrier(
            color: const Color(0x000000).withAlpha(196),
            obscure: false,
            onDismiss: _closeSshPicker,
          ),
          Center(
            child: SshConnectionLibrary(
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
          ),
        ],
      );
    }

    final dockerSourceType = dockerPickerSourceType;
    if (dockerSourceType != null) {
      return Stack(
        children: <Widget>[
          screen,
          ModalBarrier(
            color: const Color(0x000000).withAlpha(196),
            obscure: false,
            onDismiss: _closeDockerPicker,
          ),
          Center(
            child: DockerSourcePicker(
              sourceType: dockerSourceType,
              locale: locale,
              dockerContext: dockerContext.text.trim(),
              composeFile: composeFile.text.trim(),
              initialResource: _selectedDockerReference(dockerSourceType),
              initialPath: root.text.trim().isEmpty ? '/' : root.text.trim(),
              onSelected: _selectDockerSource,
              onCancel: _closeDockerPicker,
            ),
          ),
        ],
      );
    }

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

  Widget _stepRail() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: BoxBorder.all(
          color: const Color(0x27313D),
          style: BoxBorderStyle.rounded,
        ),
        title: BorderTitle(
          text: strings('setup'),
          style: const TextStyle(color: _muted),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: WizardStep.values.map((candidate) {
          final active = candidate == step;
          final complete = candidate.index < step.index;
          final label = strings(candidate.name);
          return GestureDetector(
            onTap: () {
              if (candidate.index <= step.index) {
                setState(() {
                  step = candidate;
                  cursor = 0;
                  error = null;
                });
                if (!_stepHasTextField(candidate)) {
                  wizardFocus.requestFocus();
                }
              }
            },
            child: Container(
              color: active ? _surfaceStrong : null,
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Text(
                '${active ? '›' : complete ? '✓' : '·'} $label',
                style: TextStyle(
                  color: active
                      ? _accent
                      : complete
                          ? _success
                          : _muted,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _content() {
    final body = switch (step) {
      WizardStep.language => _languageStep(),
      WizardStep.source => _sourceStep(),
      WizardStep.details => _detailsStep(),
      WizardStep.algorithms => _algorithmStep(),
      WizardStep.exclusions => _exclusionStep(),
      WizardStep.output => _outputStep(),
      WizardStep.review => _reviewStep(),
    };
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: BoxBorder.all(
          color: const Color(0x27313D),
          style: BoxBorderStyle.rounded,
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: SingleChildScrollView(child: body)),
          const SizedBox(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              _ActionButton(label: strings('back'), onTap: _back, muted: true),
              const SizedBox(width: 1),
              _ActionButton(
                label: step == WizardStep.review
                    ? strings('saveProfile')
                    : strings('next'),
                onTap: _next,
                disabled: saving,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _languageStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionTitle(
              strings('chooseLanguage'), strings('noAlgorithmDefault')),
          const SizedBox(height: 1),
          ...CentraStrings.locales.asMap().entries.map(
                (entry) => _OptionTile(
                  selected: draft.locale == entry.value.code,
                  focused: cursor == entry.key,
                  title: entry.value.nativeName,
                  subtitle: entry.value.code,
                  onTap: () => _activate(entry.key, continueAfter: true),
                ),
              ),
        ],
      );

  Widget _sourceStep() {
    final sourceLabels = <SourceType, String>{
      SourceType.local: strings('localFolder'),
      SourceType.ssh: strings('sshFolder'),
      SourceType.dockerContainer: strings('dockerContainer'),
      SourceType.dockerImage: strings('dockerImage'),
      SourceType.dockerCompose: strings('dockerCompose'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionTitle(
          strings('chooseSource'),
          'Local, SSH, Docker and Compose use the same manifest pipeline.',
        ),
        const SizedBox(height: 1),
        ...SourceType.values.asMap().entries.map(
              (entry) => _OptionTile(
                selected: draft.sourceType == entry.value,
                focused: cursor == entry.key,
                title: sourceLabels[entry.value]!,
                subtitle: entry.value.wireName,
                onTap: () => _activate(entry.key, continueAfter: true),
              ),
            ),
      ],
    );
  }

  Widget _detailsStep() {
    final fields = <Widget>[
      _field(
        strings('profileName'),
        profileName,
        profileNameFocus,
        'Production application',
        autofocus: true,
      ),
      _field(strings('profileId'), profileId, profileIdFocus, 'production-app'),
    ];
    switch (draft.sourceType) {
      case SourceType.local:
        fields.add(
          _field(
            strings('rootPath'),
            root,
            rootFocus,
            Directory.current.path,
            trailing: _ActionButton(
              label: folderStrings.browse,
              onTap: () => _openFolderPicker(root, rootFocus),
              muted: true,
            ),
          ),
        );
        break;
      case SourceType.ssh:
        fields.add(_sshSelectionPanel());
        break;
      case SourceType.dockerContainer:
        fields.addAll(<Widget>[
          _field(
            strings('dockerContext'),
            dockerContext,
            dockerContextFocus,
            'default',
          ),
          _dockerSelectionPanel(SourceType.dockerContainer),
        ]);
        break;
      case SourceType.dockerImage:
        fields.addAll(<Widget>[
          _field(
            strings('dockerContext'),
            dockerContext,
            dockerContextFocus,
            'default',
          ),
          _dockerSelectionPanel(SourceType.dockerImage),
        ]);
        break;
      case SourceType.dockerCompose:
        fields.addAll(<Widget>[
          _field(
            strings('composeFile'),
            composeFile,
            composeFileFocus,
            'compose.production.yml',
          ),
          _field(
            strings('dockerContext'),
            dockerContext,
            dockerContextFocus,
            'default',
          ),
          _dockerSelectionPanel(SourceType.dockerCompose),
        ]);
        break;
      case null:
        break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionTitle(
          strings('details'),
          'Secrets and passwords are never stored in the profile.',
        ),
        const SizedBox(height: 1),
        ...fields,
      ],
    );
  }

  Widget _sshSelectionPanel() {
    final connected = host.text.trim().isNotEmpty &&
        user.text.trim().isNotEmpty &&
        root.text.trim().isNotEmpty &&
        draft.hostKeyFingerprint.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: _surfaceStrong,
        border: BoxBorder.all(
          color: connected ? _accent : const Color(0x394453),
          style: BoxBorderStyle.rounded,
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                connected ? '● SSH' : '○ SSH',
                style: TextStyle(
                  color: connected ? _success : _muted,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                connected ? draft.sshAuthMethod.wireName : 'not configured',
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
          _ReviewRow(
            strings('host'),
            connected ? '${user.text}@${host.text}:${port.text}' : '—',
          ),
          _ReviewRow(strings('rootPath'), connected ? root.text : '—'),
          if (connected)
            _ReviewRow(
              'Fingerprint',
              '${draft.hostKeyType} ${draft.hostKeyFingerprint}',
            ),
          if (selectedSshServerVersion != null)
            _ReviewRow('Server', selectedSshServerVersion!),
          const SizedBox(height: 1),
          const Text(
            'Passwords and key passphrases are kept only in memory and are never written to the profile.',
            style: TextStyle(color: _muted),
          ),
          _ActionButton(
            label: connected ? 'Изменить SSH-подключение' : 'Настроить SSH',
            onTap: _openSshPicker,
            muted: connected,
          ),
        ],
      ),
    );
  }

  Widget _dockerSelectionPanel(SourceType sourceType) {
    final reference = _selectedDockerReference(sourceType) ?? '';
    final resourceLabel = switch (sourceType) {
      SourceType.dockerContainer => strings('container'),
      SourceType.dockerImage => strings('image'),
      SourceType.dockerCompose => strings('service'),
      SourceType.local || SourceType.ssh => strings('source'),
    };
    final hasSelection = reference.isNotEmpty && root.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: _surfaceStrong,
        border: BoxBorder.all(
          color: hasSelection ? _accent : const Color(0x394453),
          style: BoxBorderStyle.rounded,
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            resourceLabel,
            style: const TextStyle(color: _muted),
          ),
          Text(
            hasSelection ? (selectedDockerResourceTitle ?? reference) : '—',
            maxLines: 1,
            style: TextStyle(
              color: hasSelection ? _text : _muted,
              fontWeight: hasSelection ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            strings('rootPath'),
            style: const TextStyle(color: _muted),
          ),
          Text(
            hasSelection ? root.text.trim() : '—',
            maxLines: 1,
            style: TextStyle(color: hasSelection ? _accent : _muted),
          ),
          const SizedBox(height: 1),
          _ActionButton(
            label: '${folderStrings.browse} Docker',
            onTap: _openDockerPicker,
            muted: !hasSelection,
          ),
        ],
      ),
    );
  }

  Widget _algorithmStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionTitle(
              strings('chooseAlgorithms'), strings('noAlgorithmDefault')),
          const SizedBox(height: 1),
          ...AlgorithmRegistry.builtIns.asMap().entries.map((entry) {
            final algorithm = entry.value;
            final warning = algorithm.id == 'md5'
                ? strings('md5Warning')
                : algorithm.warning;
            return _OptionTile(
              selected: draft.algorithmIds.contains(algorithm.id),
              focused: cursor == entry.key,
              title: '${algorithm.displayName} · ${algorithm.outputBits}-bit',
              subtitle:
                  '${strings(algorithm.status.wireName)}${warning == null ? '' : ' — $warning'}',
              status: algorithm.status,
              onTap: () => _activate(entry.key, continueAfter: false),
            );
          }),
        ],
      );

  Widget _exclusionStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionTitle(strings('exclusions'), strings('exclusionHelp')),
          const SizedBox(height: 1),
          _field(
            strings('addPattern'),
            exclusionPattern,
            exclusionPatternFocus,
            '**/private/**',
            autofocus: true,
            onSubmitted: (_) => _addExclusion(),
          ),
          _ActionButton(
            label: strings('addPattern'),
            onTap: _addExclusion,
            muted: true,
          ),
          const SizedBox(height: 1),
          Text(
            'Detected project: ${draft.projectKind}',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 1),
          ...exclusionSuggestions.asMap().entries.map(
                (entry) => _OptionTile(
                  selected: draft.excludePatterns.contains(entry.value),
                  focused: cursor == entry.key,
                  title: entry.value,
                  subtitle: _exclusionDescription(entry.value),
                  onTap: () => _activate(entry.key, continueAfter: false),
                ),
              ),
          if (draft.excludePatterns.isNotEmpty) ...<Widget>[
            const SizedBox(height: 1),
            const Text(
              'Selected policy',
              style: TextStyle(color: _accent, fontWeight: FontWeight.bold),
            ),
            ...draft.excludePatterns
                .where((pattern) => !exclusionSuggestions.contains(pattern))
                .map(
                  (pattern) => GestureDetector(
                    onTap: () =>
                        setState(() => draft.excludePatterns.remove(pattern)),
                    child: Text('× $pattern',
                        style: const TextStyle(color: _text)),
                  ),
                ),
          ],
        ],
      );

  String _exclusionDescription(String pattern) {
    if (pattern.contains('.env') ||
        pattern.endsWith('.key') ||
        pattern.endsWith('.pem')) {
      return 'Sensitive material';
    }
    if (pattern.contains('node_modules') ||
        pattern.contains('_build') ||
        pattern.contains('target')) {
      return 'Generated dependency/build data';
    }
    if (pattern.contains('uploads') || pattern.contains('backups'))
      return 'Runtime or user-managed data';
    return 'Suggested by project detection';
  }

  Widget _outputStep() {
    final options = <({String title, String subtitle, bool selected})>[
      (
        title: strings('canonicalJson'),
        subtitle: '*.centra.json',
        selected: draft.canonicalJson,
      ),
      (
        title: strings('compatibilityText'),
        subtitle: 'hash_values.txt',
        selected: draft.compatibilityText,
      ),
      (
        title: strings('zipPackage'),
        subtitle: '*.zip',
        selected: draft.zipPackage,
      ),
      (
        title: strings('metadataReport'),
        subtitle: '*.report.json',
        selected: draft.metadataReport,
      ),
      (
        title: strings('requireZipPassword'),
        subtitle: 'Password is requested only when scanning',
        selected: draft.requireZipPassword,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionTitle(strings('output'), strings('outputHelp')),
        const SizedBox(height: 1),
        _field(
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
        ...options.asMap().entries.map(
              (entry) => _OptionTile(
                selected: entry.value.selected,
                focused: cursor == entry.key,
                title: entry.value.title,
                subtitle: entry.value.subtitle,
                disabled: entry.key == 4 && !draft.zipPackage,
                onTap: () => _activate(entry.key, continueAfter: false),
              ),
            ),
      ],
    );
  }

  Widget _reviewStep() {
    _syncDraft();
    final profileErrors = draft.validateStep(WizardStep.review);
    final algorithms = draft.algorithmIds.map(
      (id) => AlgorithmRegistry(
        customAlgorithms: draft.customAlgorithms,
      ).descriptor(id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionTitle(
          strings('review'),
          'Review every policy choice before saving.',
        ),
        const SizedBox(height: 1),
        _ReviewRow('Profile', '${draft.profileName} (${draft.profileId})'),
        _ReviewRow(strings('language'), draft.locale ?? '—'),
        _ReviewRow(strings('source'), draft.sourceType?.wireName ?? '—'),
        _ReviewRow(strings('rootPath'), draft.root),
        _ReviewRow(
          strings('algorithms'),
          algorithms.map((algorithm) => algorithm.displayName).join(', '),
        ),
        _ReviewRow(
          strings('exclusions'),
          draft.excludePatterns.isEmpty
              ? 'None'
              : '${draft.excludePatterns.length} rules',
        ),
        _ReviewRow(strings('outputDirectory'), draft.outputDirectory),
        _ReviewRow(
          strings('output'),
          <String>[
            if (draft.canonicalJson) 'JSON',
            if (draft.compatibilityText) 'Text',
            if (draft.zipPackage) 'ZIP',
            if (draft.metadataReport) 'Report',
          ].join(', '),
        ),
        const SizedBox(height: 1),
        if (algorithms.any(
          (algorithm) => algorithm.status == AlgorithmStatus.obsolete,
        ))
          _Notice(
            'Obsolete algorithms are enabled. Their warnings will be embedded in every report.',
            _warning,
          ),
        if (profileErrors.isNotEmpty) _Notice(profileErrors.join(' '), _danger),
      ],
    );
  }

  Widget _field(
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
        placeholderStyle: const TextStyle(
          color: _muted,
          fontStyle: FontStyle.italic,
        ),
        decoration: InputDecoration(
          fillColor: _surfaceStrong,
          border: BoxBorder.all(
            color: const Color(0x394453),
            style: BoxBorderStyle.rounded,
          ),
          focusedBorder: BoxBorder.all(
            color: _accent,
            style: BoxBorderStyle.rounded,
          ),
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
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({
    required this.profiles,
    required this.locale,
    required this.sshSecrets,
    required this.onNewProfile,
  });

  final List<CentraProfile> profiles;
  final String locale;
  final Map<String, SshConnectionSecrets> sshSecrets;
  final VoidCallback onNewProfile;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  var selected = 0;
  var running = false;
  var status = 'ready';
  ScanProgress? progress;
  String? message;
  CentraManifest? lastManifest;
  final password = TextEditingController();
  final verifyPath = TextEditingController();
  final sshPassword = TextEditingController();
  final sshKeyPassphrase = TextEditingController();
  final dashboardFocus = FocusNode(debugLabel: 'Centra dashboard');
  final passwordFocus = FocusNode(debugLabel: 'ZIP password');
  final verifyPathFocus = FocusNode(debugLabel: 'Manifest path');
  final sshPasswordFocus = FocusNode(debugLabel: 'SSH password');
  final sshKeyPassphraseFocus = FocusNode(debugLabel: 'SSH key passphrase');
  var showPassword = false;
  var showVerify = false;
  var showSshCredentials = false;

  CentraStrings get strings => CentraStrings(widget.locale);
  CentraProfile get profile {
    final index = selected.clamp(0, widget.profiles.length - 1);
    return widget.profiles[index];
  }

  @override
  void dispose() {
    password.dispose();
    verifyPath.dispose();
    sshPassword.dispose();
    sshKeyPassphrase.dispose();
    dashboardFocus.dispose();
    passwordFocus.dispose();
    verifyPathFocus.dispose();
    sshPasswordFocus.dispose();
    sshKeyPassphraseFocus.dispose();
    super.dispose();
  }

  bool _handleKey(KeyboardEvent event) {
    if (event.matches(LogicalKey.keyQ, ctrl: true)) {
      shutdownApp();
      return true;
    }
    if (passwordFocus.hasPrimaryFocus ||
        verifyPathFocus.hasPrimaryFocus ||
        sshPasswordFocus.hasPrimaryFocus ||
        sshKeyPassphraseFocus.hasPrimaryFocus) {
      return false;
    }
    if (event.logicalKey == LogicalKey.keyQ) {
      shutdownApp();
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowUp && widget.profiles.isNotEmpty) {
      setState(
        () => selected =
            selected <= 0 ? widget.profiles.length - 1 : selected - 1,
      );
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowDown &&
        widget.profiles.isNotEmpty) {
      setState(() => selected = (selected + 1) % widget.profiles.length);
      return true;
    }
    if (event.logicalKey == LogicalKey.keyN) {
      widget.onNewProfile();
      return true;
    }
    if (event.logicalKey == LogicalKey.keyS) {
      _startScan();
      return true;
    }
    if (event.logicalKey == LogicalKey.keyV) {
      setState(() => showVerify = !showVerify);
      return true;
    }
    return false;
  }

  Future<void> _startScan() async {
    if (running) return;
    if (profile.source.type == SourceType.ssh &&
        profile.source.sshAuthMethod.usesPassword &&
        !(widget.sshSecrets[profile.id]?.hasPassword ?? false)) {
      setState(() => showSshCredentials = true);
      return;
    }
    if (profile.output.createZip &&
        profile.output.requireZipPassword &&
        password.text.isEmpty) {
      setState(() => showPassword = true);
      return;
    }
    setState(() {
      running = true;
      status = 'scanning';
      message = null;
      progress = null;
    });
    try {
      final result = await IntegrityScanner().scan(
        profile,
        sshSecrets: widget.sshSecrets[profile.id],
        onProgress: (value) {
          if (mounted) setState(() => progress = value);
        },
      );
      await OutputService().write(
        profile,
        result.manifest,
        zipPassword: password.text.isEmpty ? null : password.text,
      );
      if (!mounted) return;
      setState(() {
        lastManifest = result.manifest;
        status = 'completed';
        message =
            'Manifest ${result.manifest.id} written to ${profile.output.directory}';
        showPassword = false;
        password.clear();
      });
    } on Object catch (error) {
      if (mounted) {
        final text = error.toString();
        setState(() {
          status = 'failed';
          message = text;
          if (profile.source.type == SourceType.ssh &&
              (text.contains('password is required') ||
                  text.contains('passphrase is required'))) {
            showSshCredentials = true;
          }
        });
      }
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  Future<void> _verify() async {
    if (running || verifyPath.text.trim().isEmpty) return;
    setState(() {
      running = true;
      status = 'scanning';
      message = null;
    });
    try {
      final approved = await const ManifestCodec().read(
        File(verifyPath.text.trim()),
      );
      final current = (await IntegrityScanner().scan(
        profile,
        sshSecrets: widget.sshSecrets[profile.id],
        onProgress: (value) {
          if (mounted) setState(() => progress = value);
        },
      ))
          .manifest;
      final diff = const ManifestComparator().compare(approved, current);
      if (!mounted) return;
      setState(() {
        status = diff.hasIntegrityChanges ? 'failed' : 'completed';
        message = diff.hasIntegrityChanges
            ? '${diff.count(ManifestChangeType.added)} added, ${diff.count(ManifestChangeType.removed)} removed, ${diff.count(ManifestChangeType.modified)} modified'
            : 'Verified: no integrity changes.';
        lastManifest = current;
      });
    } on Object catch (error) {
      if (mounted) setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  void _saveSshCredentials() {
    widget.sshSecrets[profile.id] = SshConnectionSecrets(
      password: sshPassword.text.isEmpty ? null : sshPassword.text,
      keyPassphrase:
          sshKeyPassphrase.text.isEmpty ? null : sshKeyPassphrase.text,
    );
    setState(() => showSshCredentials = false);
    _startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: dashboardFocus,
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
              trailing: strings(status),
            ),
            const SizedBox(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(width: 32, child: _profileList()),
                  const SizedBox(width: 1),
                  Expanded(child: _details()),
                ],
              ),
            ),
            const SizedBox(height: 1),
            _Footer(
              left:
                  '↑↓ ${strings('profiles')}  N ${strings('newProfile')}  S ${strings('scanNow')}  V ${strings('verify')}',
              right: 'Q ${strings('quit')}',
              warning: status == 'failed',
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileList() => Container(
        decoration: BoxDecoration(
          color: _surface,
          border: BoxBorder.all(
            color: const Color(0x27313D),
            style: BoxBorderStyle.rounded,
          ),
          title: BorderTitle(
            text: strings('profiles'),
            style: const TextStyle(color: _muted),
          ),
        ),
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ...widget.profiles.asMap().entries.map(
                  (entry) => GestureDetector(
                    onTap: () => setState(() => selected = entry.key),
                    child: Container(
                      color: selected == entry.key ? _surfaceStrong : null,
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            '${selected == entry.key ? '›' : ' '} ${entry.value.name}',
                            style: TextStyle(
                              color: selected == entry.key ? _accent : _text,
                              fontWeight: selected == entry.key
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            '  ${entry.value.source.type.wireName}',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 1),
            _ActionButton(
              label: '+ ${strings('newProfile')}',
              onTap: widget.onNewProfile,
              muted: true,
            ),
          ],
        ),
      );

  Widget _details() {
    final algorithms = profile.algorithmIds
        .map(
          (id) => AlgorithmRegistry(
            customAlgorithms: profile.customAlgorithms,
          ).descriptor(id),
        )
        .toList(growable: false);
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: BoxBorder.all(
          color: const Color(0x27313D),
          style: BoxBorderStyle.rounded,
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              profile.name,
              style: const TextStyle(color: _text, fontWeight: FontWeight.bold),
            ),
            Text(profile.id, style: const TextStyle(color: _muted)),
            const SizedBox(height: 1),
            _ReviewRow(strings('source'), profile.source.type.wireName),
            _ReviewRow(strings('rootPath'), profile.source.root),
            if (profile.source.type == SourceType.ssh) ...<Widget>[
              _ReviewRow(
                strings('host'),
                '${profile.source.user}@${profile.source.host}:${profile.source.port}',
              ),
              _ReviewRow('SSH auth', profile.source.sshAuthMethod.wireName),
              _ReviewRow(
                'Host fingerprint',
                '${profile.source.hostKeyType ?? ''} ${profile.source.hostKeyFingerprint ?? ''}',
              ),
            ],
            _ReviewRow(
              strings('algorithms'),
              algorithms.map((algorithm) => algorithm.displayName).join(', '),
            ),
            _ReviewRow(
              strings('exclusions'),
              '${profile.excludePatterns.length} rules',
            ),
            _ReviewRow(strings('outputDirectory'), profile.output.directory),
            if (algorithms.any(
              (algorithm) => algorithm.status == AlgorithmStatus.obsolete,
            ))
              const _Notice(
                'This profile contains an obsolete algorithm. Compatibility does not equal security.',
                _warning,
              ),
            const SizedBox(height: 1),
            Row(
              children: <Widget>[
                _ActionButton(
                  label: strings('scanNow'),
                  onTap: _startScan,
                  disabled: running,
                ),
                const SizedBox(width: 1),
                _ActionButton(
                  label: strings('verify'),
                  onTap: () => setState(() => showVerify = !showVerify),
                  muted: true,
                ),
              ],
            ),
            if (showSshCredentials) ...<Widget>[
              const SizedBox(height: 1),
              const _Notice(
                'SSH secrets are used only for this application session and are never saved.',
                _accent,
              ),
              if (profile.source.sshAuthMethod.usesPassword) ...<Widget>[
                const Text('SSH password', style: TextStyle(color: _muted)),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: sshPasswordFocus.requestFocus,
                  child: TextField(
                    controller: sshPassword,
                    focusNode: sshPasswordFocus,
                    autofocus: true,
                    obscureText: true,
                    width: 50,
                    placeholder: 'Required for this connection',
                    decoration: InputDecoration(
                      fillColor: _surfaceStrong,
                      border: BoxBorder.all(
                        color: const Color(0x394453),
                        style: BoxBorderStyle.rounded,
                      ),
                      focusedBorder: BoxBorder.all(
                        color: _accent,
                        style: BoxBorderStyle.rounded,
                      ),
                    ),
                  ),
                ),
              ],
              if (profile.source.sshAuthMethod.usesPrivateKey) ...<Widget>[
                const Text(
                  'SSH key passphrase (optional)',
                  style: TextStyle(color: _muted),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: sshKeyPassphraseFocus.requestFocus,
                  child: TextField(
                    controller: sshKeyPassphrase,
                    focusNode: sshKeyPassphraseFocus,
                    obscureText: true,
                    width: 50,
                    placeholder: 'Only for encrypted private keys',
                    decoration: InputDecoration(
                      fillColor: _surfaceStrong,
                      border: BoxBorder.all(
                        color: const Color(0x394453),
                        style: BoxBorderStyle.rounded,
                      ),
                      focusedBorder: BoxBorder.all(
                        color: _accent,
                        style: BoxBorderStyle.rounded,
                      ),
                    ),
                    onSubmitted: (_) => _saveSshCredentials(),
                  ),
                ),
              ],
              Row(
                children: <Widget>[
                  _ActionButton(
                    label: strings('cancel'),
                    onTap: () => setState(() => showSshCredentials = false),
                    muted: true,
                  ),
                  const SizedBox(width: 1),
                  _ActionButton(
                    label: 'Подключиться и сканировать',
                    onTap: _saveSshCredentials,
                  ),
                ],
              ),
            ],
            if (showPassword) ...<Widget>[
              const SizedBox(height: 1),
              const Text('ZIP password', style: TextStyle(color: _muted)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: passwordFocus.requestFocus,
                child: TextField(
                  controller: password,
                  focusNode: passwordFocus,
                  autofocus: true,
                  obscureText: true,
                  width: 50,
                  placeholder: 'Enter at scan time; never stored',
                  decoration: InputDecoration(
                    fillColor: _surfaceStrong,
                    border: BoxBorder.all(
                      color: const Color(0x394453),
                      style: BoxBorderStyle.rounded,
                    ),
                    focusedBorder: BoxBorder.all(
                      color: _accent,
                      style: BoxBorderStyle.rounded,
                    ),
                  ),
                  onSubmitted: (_) => _startScan(),
                ),
              ),
              _ActionButton(label: strings('scanNow'), onTap: _startScan),
            ],
            if (showVerify) ...<Widget>[
              const SizedBox(height: 1),
              const Text(
                'Approved manifest path',
                style: TextStyle(color: _muted),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: verifyPathFocus.requestFocus,
                child: TextField(
                  controller: verifyPath,
                  focusNode: verifyPathFocus,
                  autofocus: true,
                  width: 68,
                  placeholder: '/secure/baselines/application.centra.json',
                  decoration: InputDecoration(
                    fillColor: _surfaceStrong,
                    border: BoxBorder.all(
                      color: const Color(0x394453),
                      style: BoxBorderStyle.rounded,
                    ),
                    focusedBorder: BoxBorder.all(
                      color: _accent,
                      style: BoxBorderStyle.rounded,
                    ),
                  ),
                  onSubmitted: (_) => _verify(),
                ),
              ),
              _ActionButton(label: strings('verify'), onTap: _verify),
            ],
            if (progress != null) ...<Widget>[
              const SizedBox(height: 1),
              Text(
                '${progress!.phase}  ${progress!.completed}/${progress!.discovered}  ${progress!.currentPath ?? ''}',
                style: const TextStyle(color: _accent),
              ),
            ],
            if (lastManifest != null) ...<Widget>[
              const SizedBox(height: 1),
              _ReviewRow(
                strings('files'),
                lastManifest!.files.length.toString(),
              ),
              _ReviewRow(strings('bytes'), lastManifest!.totalBytes.toString()),
            ],
            if (message != null) ...<Widget>[
              const SizedBox(height: 1),
              _Notice(message!, status == 'failed' ? _danger : _success),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) => Container(
        color: _surface,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Row(
          children: <Widget>[
            Text(
              title,
              style:
                  const TextStyle(color: _accent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(subtitle, style: const TextStyle(color: _muted)),
            ),
            Text(trailing, style: const TextStyle(color: _text)),
          ],
        ),
      );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.left,
    required this.right,
    required this.warning,
  });

  final String left;
  final String right;
  final bool warning;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: Text(
              left,
              style: TextStyle(color: warning ? _warning : _muted),
              maxLines: 1,
            ),
          ),
          Text(right, style: const TextStyle(color: _muted)),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(color: _text, fontWeight: FontWeight.bold),
          ),
          Text(subtitle, style: const TextStyle(color: _muted)),
        ],
      );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.selected,
    required this.focused,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.status,
    this.disabled = false,
  });

  final bool selected;
  final bool focused;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final AlgorithmStatus? status;
  final bool disabled;

  Color get statusColor => switch (status) {
        AlgorithmStatus.recommended => _success,
        AlgorithmStatus.acceptable => const Color(0x58A6FF),
        AlgorithmStatus.legacy => _warning,
        AlgorithmStatus.obsolete => _danger,
        AlgorithmStatus.checksum => const Color(0xBC8CFF),
        AlgorithmStatus.custom => _accent,
        null => _muted,
      };

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          color: focused ? _surfaceStrong : null,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                disabled
                    ? '[-]'
                    : selected
                        ? '[✓]'
                        : '[ ]',
                style: TextStyle(
                  color: disabled
                      ? _muted
                      : selected
                          ? _accent
                          : _muted,
                ),
              ),
              const SizedBox(width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(title,
                        style: TextStyle(color: disabled ? _muted : _text)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight:
                            status == null ? FontWeight.normal : FontWeight.dim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.muted = false,
    this.disabled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool muted;
  final bool disabled;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          color: disabled
              ? const Color(0x27313D)
              : muted
                  ? _surfaceStrong
                  : _accent,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            style: TextStyle(
              color: disabled
                  ? _muted
                  : muted
                      ? _text
                      : _background,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 22,
              child: Text(label, style: const TextStyle(color: _muted)),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(color: _text),
              ),
            ),
          ],
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, this.color);

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _surfaceStrong,
          border: BoxBorder.all(color: color, style: BoxBorderStyle.rounded),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Text(message, style: TextStyle(color: color)),
      );
}
