import 'dart:io';

import 'package:cinder/cinder.dart';

import '../core/manifest.dart';
import '../core/profile.dart';
import '../core/scanner.dart';
import '../core/services.dart';
import '../core/ssh_connection.dart';
import '../core/storage.dart';
import '../core/trusted_baseline.dart';
import 'profile_scan_settings_panel.dart';
import 'scan_estimate_panel.dart';
import 'scan_progress_panel.dart';
import 'scan_result_panel.dart';
import 'source_change_panel.dart';

const _dashAccent = Color(0x64D8CB);
const _dashBackground = Color(0x0D1117);
const _dashSurface = Color(0x151B23);
const _dashSurfaceStrong = Color(0x1D2632);
const _dashMuted = Color(0x7D8A99);
const _dashText = Color(0xE6EDF3);
const _dashWarning = Color(0xE3B341);
const _dashDanger = Color(0xF47067);
const _dashSuccess = Color(0x56D364);

enum _DashboardStage {
  idle,
  credentials,
  preparing,
  estimate,
  scanning,
  result,
  source,
  policy,
}

class ProductionDashboard extends StatefulWidget {
  const ProductionDashboard({
    super.key,
    required this.profiles,
    required this.locale,
    required this.sshSecrets,
    required this.profileStore,
    required this.onProfilesChanged,
    required this.onNewProfile,
    required this.onSettings,
  });

  final List<CentraProfile> profiles;
  final String locale;
  final Map<String, SshConnectionSecrets> sshSecrets;
  final ProfileStore profileStore;
  final ValueChanged<List<CentraProfile>> onProfilesChanged;
  final VoidCallback onNewProfile;
  final VoidCallback onSettings;

  @override
  State<ProductionDashboard> createState() => _ProductionDashboardState();
}

class _ProductionDashboardState extends State<ProductionDashboard> {
  final scanner = IntegrityScanner();
  final outputService = OutputService();
  final baselineService = TrustedBaselineService();
  final focusNode = FocusNode(debugLabel: 'Centra production dashboard');
  var selected = 0;
  var stage = _DashboardStage.idle;
  ScanCancellationToken? cancellationToken;
  PreparedScan? preparedScan;
  ScanProgress? progress;
  ScanResult? result;
  ScanArtifacts? artifacts;
  TrustedBaselineVerification? trustedBaseline;
  ManifestDiff? baselineDiff;
  String? status;
  String? error;
  String? zipPassword;
  var cancelling = false;
  var changeSourceAfterCancel = false;

  CentraProfile? get profile => widget.profiles.isEmpty
      ? null
      : widget.profiles[selected.clamp(0, widget.profiles.length - 1)];
  bool get ru => widget.locale == 'ru';
  String t(String en, String ru) => this.ru ? ru : en;

  @override
  void didUpdateWidget(covariant ProductionDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (selected >= widget.profiles.length) {
      selected = widget.profiles.isEmpty ? 0 : widget.profiles.length - 1;
    }
  }

  @override
  void dispose() {
    cancellationToken?.cancel();
    preparedScan?.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyboardListener(
        focusNode: focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Container(
          color: _dashBackground,
          padding: const EdgeInsets.all(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _header(),
              const SizedBox(height: 1),
              Expanded(
                child: switch (stage) {
                  _DashboardStage.credentials => _credentials(),
                  _DashboardStage.source => _sourceEditor(),
                  _DashboardStage.policy => _policyEditor(),
                  _ => Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(width: 30, child: _profileList()),
                        const SizedBox(width: 1),
                        Expanded(child: _main()),
                      ],
                    ),
                },
              ),
              const SizedBox(height: 1),
              _footer(),
            ],
          ),
        ),
      );

  Widget _header() => Container(
        color: _dashSurface,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Row(
          children: <Widget>[
            const Text(
              'CENTRA',
              style: TextStyle(
                color: _dashAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                t('File integrity and trusted deployment verification',
                    'Контроль целостности и доверенных развёртываний'),
                style: const TextStyle(color: _dashMuted),
              ),
            ),
            _headerButton(t('Settings', 'Настройки'), widget.onSettings),
            const SizedBox(width: 1),
            _headerButton(t('Scan policy', 'Политика'),
                profile == null ? null : () => setState(() => stage = _DashboardStage.policy)),
          ],
        ),
      );

  Widget _profileList() => Container(
        decoration: BoxDecoration(
          color: _dashSurface,
          border: BoxBorder.all(
            color: const Color(0x394453),
            style: BoxBorderStyle.rounded,
          ),
          title: BorderTitle(text: t('Profiles', 'Профили')),
        ),
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                itemCount: widget.profiles.length,
                itemBuilder: (context, index) {
                  final value = widget.profiles[index];
                  return GestureDetector(
                    onTap: stage == _DashboardStage.idle ||
                            stage == _DashboardStage.result
                        ? () => setState(() {
                              selected = index;
                              stage = _DashboardStage.idle;
                              result = null;
                              artifacts = null;
                              baselineDiff = null;
                              error = null;
                            })
                        : null,
                    child: Container(
                      color: index == selected ? _dashSurfaceStrong : null,
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            '${index == selected ? '›' : ' '} ${value.name}',
                            maxLines: 1,
                            style: TextStyle(
                              color: index == selected
                                  ? _dashAccent
                                  : _dashText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            value.source.sshConnectionName ??
                                value.source.type.wireName,
                            maxLines: 1,
                            style: const TextStyle(color: _dashMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _button(t('+ New profile', '+ Новый профиль'),
                stage == _DashboardStage.idle ? widget.onNewProfile : null,
                muted: true),
          ],
        ),
      );

  Widget _main() {
    final value = profile;
    if (value == null) {
      return Center(child: Text(t('No profiles.', 'Профилей нет.')));
    }
    if (stage == _DashboardStage.preparing ||
        stage == _DashboardStage.scanning) {
      return ScanProgressPanel(
        progress: progress ??
            ScanProgress(
              phase: value.source.type == SourceType.ssh
                  ? 'ssh-connect'
                  : 'source-prepare',
              discovered: 0,
              completed: 0,
              totalBytes: 0,
              currentPath: value.source.root,
            ),
        translate: _translate,
        cancelling: cancelling,
        onCancel: () => _cancel(false),
        onCancelAndEdit: () => _cancel(true),
      );
    }
    if (stage == _DashboardStage.estimate && preparedScan != null) {
      return ScanEstimatePanel(
        estimate: preparedScan!.estimate,
        fullVerification:
            value.verificationMode == VerificationMode.full,
        translate: _translate,
        onStart: _executePreparedScan,
        onCancel: () => _cancelPrepared(false),
        onChangeSource: () => _cancelPrepared(true),
      );
    }
    if (stage == _DashboardStage.result && result != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: ScanResultPanel(
              result: result!,
              artifacts: artifacts,
              translate: _translate,
              onOpenReport: _openReport,
              onCompare: _showComparison,
              onExport: _showArtifacts,
              onRepeat: _beginScan,
              onChangeSource: () => setState(() => stage = _DashboardStage.source),
            ),
          ),
          if (trustedBaseline != null || baselineDiff != null)
            _baselineStatus(),
        ],
      );
    }
    return _idle(value);
  }

  Widget _idle(CentraProfile value) => Container(
        decoration: BoxDecoration(
          color: _dashSurface,
          border: BoxBorder.all(
            color: const Color(0x394453),
            style: BoxBorderStyle.rounded,
          ),
        ),
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(value.name,
                style: const TextStyle(
                    color: _dashText, fontWeight: FontWeight.bold)),
            Text(value.id, style: const TextStyle(color: _dashMuted)),
            const SizedBox(height: 1),
            _detail(t('Source', 'Источник'), value.source.type.wireName),
            if (value.source.type == SourceType.ssh)
              _detail(t('Connection', 'Подключение'),
                  value.source.sshConnectionName ?? '${value.source.user}@${value.source.host}:${value.source.port}'),
            _detail(t('Directory', 'Папка'), value.source.root),
            _detail(t('Algorithms', 'Алгоритмы'), value.algorithmIds.join(', ')),
            _detail(t('Verification', 'Проверка'), value.verificationMode == VerificationMode.full ? t('Full', 'Полная') : t('Fast · weaker', 'Быстрая · слабее')),
            _detail(t('Read policy', 'Ошибки чтения'), value.effectiveReadErrorPolicy.wireName),
            _detail(t('Exclusions', 'Исключения'), '${value.excludePatterns.length} ${t('rules', 'правил')}'),
            _detail(t('Output', 'Результат'), value.output.directory),
            if (value.algorithmIds.contains('md5'))
              Container(
                color: const Color(0x302A18),
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(
                  t('MD5 is obsolete and unsuitable for security. Use it only for compatibility.',
                      'MD5 устарел и не подходит для защиты. Используйте его только для совместимости.'),
                  style: const TextStyle(color: _dashWarning),
                ),
              ),
            if (status != null)
              Text(status!, style: const TextStyle(color: _dashSuccess)),
            if (error != null)
              Text(error!, maxLines: 4, style: const TextStyle(color: _dashDanger)),
            const Spacer(),
            Row(
              children: <Widget>[
                _button(t('Change directory', 'Изменить папку'),
                    () => setState(() => stage = _DashboardStage.source),
                    muted: true),
                const SizedBox(width: 1),
                _button(t('Scan policy', 'Политика'),
                    () => setState(() => stage = _DashboardStage.policy),
                    muted: true),
                const Spacer(),
                _button(t('Estimate and scan', 'Оценить и сканировать'), _beginScan),
              ],
            ),
          ],
        ),
      );

  Widget _credentials() => _ScanCredentialsPrompt(
        locale: widget.locale,
        profile: profile!,
        existing: widget.sshSecrets[profile!.id],
        onSubmit: (secrets, password) {
          widget.sshSecrets[profile!.id] = secrets;
          zipPassword = password;
          setState(() => stage = _DashboardStage.idle);
          _prepareScan();
        },
        onCancel: () => setState(() => stage = _DashboardStage.idle),
      );

  Widget _sourceEditor() => SourceChangePanel(
        profile: profile!,
        locale: widget.locale,
        onSelected: (selection) async {
          await widget.profileStore.save(selection.$1);
          if (selection.$2 != null) {
            widget.sshSecrets[selection.$1.id] = selection.$2!;
          }
          await _refreshProfiles();
          if (mounted) setState(() => stage = _DashboardStage.idle);
        },
        onCancel: () => setState(() => stage = _DashboardStage.idle),
      );

  Widget _policyEditor() => ProfileScanSettingsPanel(
        profile: profile!,
        locale: widget.locale,
        onSaved: (updated) async {
          await widget.profileStore.save(updated);
          await _refreshProfiles();
          if (mounted) setState(() => stage = _DashboardStage.idle);
        },
        onCancel: () => setState(() => stage = _DashboardStage.idle),
      );

  Future<void> _refreshProfiles() async {
    final refreshed = await widget.profileStore.list();
    widget.onProfilesChanged(refreshed);
  }

  void _beginScan() {
    final value = profile;
    if (value == null) return;
    final needsSshSecrets = value.source.type == SourceType.ssh &&
        (value.source.sshAuthMethod.usesPassword ||
            value.source.sshAuthMethod.usesPrivateKey) &&
        !widget.sshSecrets.containsKey(value.id);
    final needsZipPassword = value.output.createZip &&
        value.output.requireZipPassword &&
        (zipPassword == null || zipPassword!.isEmpty);
    if (needsSshSecrets || needsZipPassword) {
      setState(() => stage = _DashboardStage.credentials);
      return;
    }
    _prepareScan();
  }

  Future<void> _prepareScan() async {
    final value = profile;
    if (value == null) return;
    final token = ScanCancellationToken();
    cancellationToken = token;
    preparedScan = null;
    result = null;
    artifacts = null;
    trustedBaseline = null;
    baselineDiff = null;
    setState(() {
      stage = _DashboardStage.preparing;
      progress = null;
      error = null;
      status = null;
      cancelling = false;
    });
    try {
      final trust = await baselineService.loadForProfile(value);
      token.throwIfCancelled();
      final prepared = await scanner.prepare(
        value,
        sshSecrets: widget.sshSecrets[value.id],
        cancellationToken: token,
        onProgress: (update) {
          if (mounted) setState(() => progress = update);
        },
      );
      if (!mounted) {
        await prepared.dispose();
        return;
      }
      setState(() {
        trustedBaseline = trust;
        preparedScan = prepared;
        stage = _DashboardStage.estimate;
      });
    } on ScanCancelledException {
      _finishCancellation();
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        stage = _DashboardStage.idle;
        error = exception.toString();
        cancelling = false;
      });
    }
  }

  Future<void> _executePreparedScan() async {
    final prepared = preparedScan;
    final value = profile;
    if (prepared == null || value == null) return;
    setState(() {
      stage = _DashboardStage.scanning;
      cancelling = false;
    });
    try {
      final scan = await prepared.run(
        baseline: trustedBaseline?.manifest,
        verificationMode: value.verificationMode,
        baselineMetadata: trustedBaseline?.toManifestMetadata(),
      );
      final written = await outputService.write(
        value,
        scan.manifest,
        zipPassword: zipPassword,
      );
      final comparison = trustedBaseline == null
          ? null
          : const ManifestComparator().compare(
              trustedBaseline!.manifest,
              scan.manifest,
            );
      if (!mounted) return;
      setState(() {
        result = scan;
        artifacts = written;
        baselineDiff = comparison;
        stage = _DashboardStage.result;
        preparedScan = null;
        cancellationToken = null;
        cancelling = false;
      });
    } on ScanCancelledException {
      _finishCancellation();
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        stage = _DashboardStage.idle;
        error = exception.toString();
        preparedScan = null;
        cancellationToken = null;
        cancelling = false;
      });
    }
  }

  void _cancel(bool editSource) {
    if (cancellationToken == null) return;
    setState(() {
      cancelling = true;
      changeSourceAfterCancel = editSource;
    });
    cancellationToken!.cancel();
  }

  Future<void> _cancelPrepared(bool editSource) async {
    setState(() => cancelling = true);
    cancellationToken?.cancel();
    await preparedScan?.dispose();
    changeSourceAfterCancel = editSource;
    _finishCancellation();
  }

  void _finishCancellation() {
    if (!mounted) return;
    final edit = changeSourceAfterCancel;
    changeSourceAfterCancel = false;
    setState(() {
      stage = edit ? _DashboardStage.source : _DashboardStage.idle;
      status = t('Scan stopped safely.', 'Сканирование безопасно остановлено.');
      preparedScan = null;
      cancellationToken = null;
      progress = null;
      cancelling = false;
    });
  }

  void _showComparison() {
    final diff = baselineDiff;
    if (diff == null) {
      setState(() => status = t('No trusted baseline configured.', 'Доверенный baseline не настроен.'));
      return;
    }
    setState(() => status = diff.hasIntegrityChanges
        ? t('Integrity changes detected.', 'Обнаружены изменения целостности.')
        : t('No integrity changes.', 'Изменений целостности нет.'));
  }

  void _openReport() {
    final report = artifacts?.artifacts
        .where((artifact) => artifact.kind == 'report')
        .firstOrNull;
    setState(() => status = report == null
        ? t('Metadata report was not requested.', 'Отчёт не был выбран в профиле.')
        : report.file.absolute.path);
  }

  void _showArtifacts() {
    final paths = <String>[
      ...?artifacts?.artifacts.map((artifact) => artifact.file.absolute.path),
      if (artifacts?.archive != null) artifacts!.archive!.file.absolute.path,
    ];
    setState(() => status = paths.isEmpty
        ? t('No output artifacts.', 'Артефактов нет.')
        : paths.join(' · '));
  }

  Widget _baselineStatus() {
    final trust = trustedBaseline;
    final diff = baselineDiff;
    return Container(
      color: _dashSurface,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        trust == null
            ? t('Baseline: not configured', 'Baseline: не настроен')
            : 'Baseline signature: VALID · '
                '${trust.signer ?? trust.signature.keyId}'
                '${trust.commit == null ? '' : ' · ${trust.commit}'}'
                '${trust.build == null ? '' : ' · ${trust.build}'}'
                '${diff == null ? '' : ' · changes: ${diff.changes.where((change) => change.type != ManifestChangeType.unchanged).length}'}',
        maxLines: 1,
        style: TextStyle(
          color: trust?.trusted == true ? _dashSuccess : _dashMuted,
        ),
      ),
    );
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.keyQ) shutdownApp();
    if (stage == _DashboardStage.idle) {
      if (event.logicalKey == LogicalKeyboardKey.keyN) widget.onNewProfile();
      if (event.logicalKey == LogicalKeyboardKey.keyS) _beginScan();
      if (event.logicalKey == LogicalKeyboardKey.keyP && profile != null) {
        setState(() => stage = _DashboardStage.policy);
      }
      if (event.logicalKey == LogicalKeyboardKey.comma) widget.onSettings();
      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          selected + 1 < widget.profiles.length) {
        setState(() => selected++);
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp && selected > 0) {
        setState(() => selected--);
      }
    } else if ((stage == _DashboardStage.preparing ||
            stage == _DashboardStage.scanning) &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel(false);
    }
  }

  String _translate(String key) => <String, String>{
        'scanProgress': t('Scan progress', 'Ход сканирования'),
        'phaseConnect': t('Connect to source', 'Подключение к источнику'),
        'phaseInventory': t('Build file inventory', 'Построение списка файлов'),
        'phaseTransfer': t('Transfer and hash stream', 'Передача и потоковое хэширование'),
        'phaseHashing': t('Finalize hashes', 'Завершение хэшей'),
        'currentFile': t('Current file', 'Текущий файл'),
        'transferred': t('Transferred', 'Передано'),
        'speed': t('Speed', 'Скорость'),
        'elapsed': t('Elapsed', 'Прошло'),
        'remaining': t('Remaining', 'Осталось'),
        'files': t('Files', 'Файлы'),
        'directories': t('Directories', 'Папки'),
        'skipped': t('Skipped', 'Пропущено'),
        'readErrors': t('Read errors', 'Ошибки чтения'),
        'calculating': t('calculating…', 'расчёт…'),
        'stopScan': t('Stop scan', 'Остановить сканирование'),
        'stopAndChangeSource': t('Stop and change directory', 'Остановить и выбрать папку'),
        'cancelling': t('Stopping…', 'Остановка…'),
        'scanEstimate': t('Scan estimate', 'Предварительная оценка'),
        'totalSize': t('Total size', 'Объём'),
        'expectedTime': t('Expected time', 'Ожидаемое время'),
        'fullVerificationDescription': t('Full verification reads and hashes every accepted file.', 'Полная проверка перечитывает и хэширует каждый принятый файл.'),
        'fastVerificationWarning': t('Fast verification is weaker: unchanged metadata reuses trusted baseline hashes.', 'Быстрая проверка слабее: при совпадении метаданных используются хэши trusted baseline.'),
        'exclusionPreview': t('Excluded before transfer', 'Исключено до передачи'),
        'noExcludedFiles': t('No excluded files found.', 'Исключённых файлов не найдено.'),
        'filesShort': t('files', 'ф.'),
        'showLess': t('Show less', 'Свернуть'),
        'showAll': t('Show all', 'Показать всё'),
        'cancel': t('Cancel', 'Отмена'),
        'changeSource': t('Change directory', 'Изменить папку'),
        'startScan': t('Start', 'Начать'),
        'scanCompleted': t('SCAN COMPLETED', 'СКАНИРОВАНИЕ ЗАВЕРШЕНО'),
        'filesHashed': t('Files hashed', 'Файлов хэшировано'),
        'directoriesVisited': t('Directories visited', 'Папок просмотрено'),
        'unstableFiles': t('Unstable files', 'Изменившихся файлов'),
        'duration': t('Duration', 'Длительность'),
        'manifest': 'Manifest',
        'issues': t('Issues', 'Проблемы'),
        'openReport': t('Open report', 'Открыть отчёт'),
        'compare': t('Compare', 'Сравнить'),
        'export': t('Export', 'Экспортировать'),
        'repeat': t('Repeat', 'Повторить'),
      }[key] ?? key;

  Widget _footer() => Row(
        children: <Widget>[
          Text('↑↓ ${t('profiles', 'профили')}', style: const TextStyle(color: _dashMuted)),
          const SizedBox(width: 2),
          Text('S ${t('scan', 'сканировать')}', style: const TextStyle(color: _dashMuted)),
          const SizedBox(width: 2),
          Text('P ${t('policy', 'политика')}', style: const TextStyle(color: _dashMuted)),
          const SizedBox(width: 2),
          Text(', ${t('settings', 'настройки')}', style: const TextStyle(color: _dashMuted)),
          const Spacer(),
          Text('Q ${t('quit', 'выход')}', style: const TextStyle(color: _dashMuted)),
        ],
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Row(
          children: <Widget>[
            SizedBox(width: 22, child: Text(label, style: const TextStyle(color: _dashMuted))),
            Expanded(child: Text(value, maxLines: 2, style: const TextStyle(color: _dashText))),
          ],
        ),
      );

  Widget _headerButton(String label, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          color: onTap == null ? const Color(0x27313D) : _dashSurfaceStrong,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(label, style: TextStyle(color: onTap == null ? _dashMuted : _dashText)),
        ),
      );

  Widget _button(String label, VoidCallback? onTap, {bool muted = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          color: onTap == null ? const Color(0x27313D) : muted ? _dashSurfaceStrong : _dashAccent,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(label, style: TextStyle(color: onTap == null ? _dashMuted : muted ? _dashText : _dashBackground, fontWeight: FontWeight.bold)),
        ),
      );
}

class _ScanCredentialsPrompt extends StatefulWidget {
  const _ScanCredentialsPrompt({
    required this.locale,
    required this.profile,
    required this.onSubmit,
    required this.onCancel,
    this.existing,
  });

  final String locale;
  final CentraProfile profile;
  final SshConnectionSecrets? existing;
  final void Function(SshConnectionSecrets secrets, String? zipPassword) onSubmit;
  final VoidCallback onCancel;

  @override
  State<_ScanCredentialsPrompt> createState() => _ScanCredentialsPromptState();
}

class _ScanCredentialsPromptState extends State<_ScanCredentialsPrompt> {
  late final TextEditingController password;
  late final TextEditingController passphrase;
  final zip = TextEditingController();

  bool get ru => widget.locale == 'ru';
  String t(String en, String ru) => this.ru ? ru : en;

  @override
  void initState() {
    super.initState();
    password = TextEditingController(text: widget.existing?.password ?? '');
    passphrase = TextEditingController(text: widget.existing?.keyPassphrase ?? '');
  }

  @override
  void dispose() {
    password.dispose();
    passphrase.dispose();
    zip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 70,
          child: Container(
            decoration: BoxDecoration(
              color: _dashSurface,
              border: BoxBorder.all(color: _dashAccent, style: BoxBorderStyle.rounded),
              title: BorderTitle(text: t('Session secrets', 'Секреты сессии')),
            ),
            padding: const EdgeInsets.all(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(t('Secrets stay in memory and are never saved.', 'Секреты остаются в памяти и никогда не сохраняются.'), style: const TextStyle(color: _dashMuted)),
                if (widget.profile.source.type == SourceType.ssh && widget.profile.source.sshAuthMethod.usesPassword) ...<Widget>[
                  Text(t('SSH password', 'SSH-пароль')),
                  TextField(controller: password, obscureText: true),
                ],
                if (widget.profile.source.type == SourceType.ssh && widget.profile.source.sshAuthMethod.usesPrivateKey) ...<Widget>[
                  Text(t('Key passphrase · optional', 'Passphrase ключа · необязательно')),
                  TextField(controller: passphrase, obscureText: true),
                ],
                if (widget.profile.output.createZip && widget.profile.output.requireZipPassword) ...<Widget>[
                  Text(t('ZIP password', 'Пароль ZIP')),
                  TextField(controller: zip, obscureText: true),
                ],
                const SizedBox(height: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    GestureDetector(onTap: widget.onCancel, child: Container(color: _dashSurfaceStrong, padding: const EdgeInsets.symmetric(horizontal: 2), child: Text(t('Cancel', 'Отмена')))),
                    const SizedBox(width: 1),
                    GestureDetector(onTap: () => widget.onSubmit(SshConnectionSecrets(password: password.text.isEmpty ? null : password.text, keyPassphrase: passphrase.text.isEmpty ? null : passphrase.text), zip.text.isEmpty ? null : zip.text), child: Container(color: _dashAccent, padding: const EdgeInsets.symmetric(horizontal: 2), child: Text(t('Continue', 'Продолжить'), style: const TextStyle(color: _dashBackground, fontWeight: FontWeight.bold)))),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
