import 'package:cinder/cinder.dart';

import '../core/profile.dart';
import '../core/profile_editor.dart';
import '../core/scan_control.dart';

const _policyAccent = Color(0x64D8CB);
const _policyBackground = Color(0x0D1117);
const _policySurface = Color(0x151B23);
const _policySurfaceStrong = Color(0x1D2632);
const _policyMuted = Color(0x7D8A99);
const _policyText = Color(0xE6EDF3);
const _policyDanger = Color(0xF47067);
const _policyWarning = Color(0xE3B341);

class ProfileScanSettingsPanel extends StatefulWidget {
  const ProfileScanSettingsPanel({
    super.key,
    required this.profile,
    required this.locale,
    required this.onSaved,
    required this.onCancel,
  });

  final CentraProfile profile;
  final String locale;
  final Future<void> Function(CentraProfile profile) onSaved;
  final VoidCallback onCancel;

  @override
  State<ProfileScanSettingsPanel> createState() =>
      _ProfileScanSettingsPanelState();
}

class _ProfileScanSettingsPanelState extends State<ProfileScanSettingsPanel> {
  late VerificationMode verificationMode;
  late ReadErrorPolicy readErrorPolicy;
  late SymlinkPolicy symlinkPolicy;
  late bool oneFileSystem;
  late final TextEditingController retries;
  late final TextEditingController unstableRetries;
  late final TextEditingController fileTimeout;
  late final TextEditingController maximumFileBytes;
  late final TextEditingController maximumTotalBytes;
  late final TextEditingController maximumFiles;
  late final TextEditingController maximumDepth;
  late final TextEditingController baselineManifest;
  late final TextEditingController baselineSignature;
  late final TextEditingController trustedPublicKey;
  late final TextEditingController trustedSigner;
  late final TextEditingController releaseCommit;
  late final TextEditingController releaseBuild;
  var saving = false;
  String? error;

  bool get ru => widget.locale == 'ru';
  String t(String en, String ru) => this.ru ? ru : en;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    verificationMode = profile.verificationMode;
    readErrorPolicy = profile.effectiveReadErrorPolicy;
    symlinkPolicy = profile.symlinkPolicy;
    oneFileSystem = profile.limits.oneFileSystem;
    retries = TextEditingController(text: profile.readRetryCount.toString());
    unstableRetries =
        TextEditingController(text: profile.unstableRetryCount.toString());
    fileTimeout = TextEditingController(
      text: profile.limits.fileTimeoutSeconds.toString(),
    );
    maximumFileBytes = TextEditingController(
      text: profile.limits.maximumFileBytes.toString(),
    );
    maximumTotalBytes = TextEditingController(
      text: profile.limits.maximumTotalBytes.toString(),
    );
    maximumFiles =
        TextEditingController(text: profile.limits.maximumFiles.toString());
    maximumDepth =
        TextEditingController(text: profile.limits.maximumDepth.toString());
    baselineManifest =
        TextEditingController(text: profile.trustedBaselineManifest ?? '');
    baselineSignature =
        TextEditingController(text: profile.trustedBaselineSignature ?? '');
    trustedPublicKey =
        TextEditingController(text: profile.trustedPublicKey ?? '');
    trustedSigner = TextEditingController(text: profile.trustedSigner ?? '');
    releaseCommit = TextEditingController(text: profile.releaseCommit ?? '');
    releaseBuild = TextEditingController(text: profile.releaseBuild ?? '');
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      retries,
      unstableRetries,
      fileTimeout,
      maximumFileBytes,
      maximumTotalBytes,
      maximumFiles,
      maximumDepth,
      baselineManifest,
      baselineSignature,
      trustedPublicKey,
      trustedSigner,
      releaseCommit,
      releaseBuild,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 106,
        height: 39,
        child: Container(
          decoration: BoxDecoration(
            color: _policyBackground,
            border: BoxBorder.all(
              color: _policyAccent,
              style: BoxBorderStyle.rounded,
            ),
            title: BorderTitle(
              text: t('Scan policy', 'Политика сканирования'),
              style: const TextStyle(
                color: _policyAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          padding: const EdgeInsets.all(1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _left()),
              const SizedBox(width: 1),
              Expanded(child: _right()),
            ],
          ),
        ),
      );

  Widget _left() => Container(
        color: _policySurface,
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _heading(t('Verification', 'Проверка')),
            _choice(
              t('Full verification', 'Полная проверка'),
              verificationMode == VerificationMode.full,
              () => setState(() => verificationMode = VerificationMode.full),
            ),
            _choice(
              t('Fast verification · weaker', 'Быстрая проверка · слабее'),
              verificationMode == VerificationMode.fast,
              () => setState(() => verificationMode = VerificationMode.fast),
              warning: true,
            ),
            const SizedBox(height: 1),
            _heading(t('Read errors', 'Ошибки чтения')),
            _choice(
              t('Stop immediately', 'Сразу остановить'),
              readErrorPolicy == ReadErrorPolicy.stop,
              () => setState(() => readErrorPolicy = ReadErrorPolicy.stop),
            ),
            _choice(
              t('Continue and report', 'Продолжить и записать'),
              readErrorPolicy == ReadErrorPolicy.continueScan,
              () => setState(
                () => readErrorPolicy = ReadErrorPolicy.continueScan,
              ),
            ),
            _choice(
              t('Retry then continue', 'Повторить, затем продолжить'),
              readErrorPolicy == ReadErrorPolicy.retry,
              () => setState(() => readErrorPolicy = ReadErrorPolicy.retry),
            ),
            _field(t('Read retries', 'Повторы чтения'), retries),
            _field(
              t('Unstable-file retries', 'Повторы изменившегося файла'),
              unstableRetries,
            ),
            _field(t('File timeout, sec', 'Таймаут файла, сек'), fileTimeout),
            const SizedBox(height: 1),
            _heading(t('Safety limits', 'Ограничения')),
            _field(
              t('Max file bytes · 0 unlimited', 'Макс. файл · 0 без лимита'),
              maximumFileBytes,
            ),
            _field(
              t('Max total bytes · 0 unlimited', 'Макс. объём · 0 без лимита'),
              maximumTotalBytes,
            ),
            _field(t('Max files', 'Макс. файлов'), maximumFiles),
            _field(t('Max depth', 'Макс. глубина'), maximumDepth),
            _toggle(
              t('Stay on one filesystem · SSH best effort',
                  'Одна файловая система · для SSH best effort'),
              oneFileSystem,
              () => setState(() => oneFileSystem = !oneFileSystem),
            ),
            _heading(t('Symbolic links', 'Символические ссылки')),
            Row(
              children: SymlinkPolicy.values
                  .map(
                    (policy) => Expanded(
                      child: _choice(
                        policy.wireName,
                        symlinkPolicy == policy,
                        () => setState(() => symlinkPolicy = policy),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      );

  Widget _right() => Container(
        color: _policySurface,
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _heading(t('Trusted signed baseline', 'Доверенный baseline')),
            Text(
              t(
                'Manifest, Ed25519 signature and public key are verified before comparison or fast verification.',
                'Manifest, подпись Ed25519 и открытый ключ проверяются до сравнения или быстрой проверки.',
              ),
              maxLines: 3,
              style: const TextStyle(color: _policyMuted),
            ),
            _field(
                t('Baseline manifest', 'Baseline manifest'), baselineManifest),
            _field(t('Signature document', 'Файл подписи'), baselineSignature),
            _field(t('Trusted public key', 'Доверенный открытый ключ'),
                trustedPublicKey),
            _field(t('Signer', 'Подписант'), trustedSigner),
            _field(t('Release commit', 'Commit релиза'), releaseCommit),
            _field(t('Build', 'Сборка'), releaseBuild),
            const Spacer(),
            if (error != null)
              Text(error!, style: const TextStyle(color: _policyDanger)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                _button(t('Cancel', 'Отмена'), widget.onCancel, muted: true),
                const SizedBox(width: 1),
                _button(
                  saving ? t('Saving…', 'Сохранение…') : t('Save', 'Сохранить'),
                  saving ? null : _save,
                ),
              ],
            ),
          ],
        ),
      );

  Future<void> _save() async {
    final values = <String, int?>{
      'retries': int.tryParse(retries.text.trim()),
      'unstableRetries': int.tryParse(unstableRetries.text.trim()),
      'fileTimeout': int.tryParse(fileTimeout.text.trim()),
      'maximumFileBytes': int.tryParse(maximumFileBytes.text.trim()),
      'maximumTotalBytes': int.tryParse(maximumTotalBytes.text.trim()),
      'maximumFiles': int.tryParse(maximumFiles.text.trim()),
      'maximumDepth': int.tryParse(maximumDepth.text.trim()),
    };
    if (values.values.any((value) => value == null)) {
      setState(() => error = t('All limits must be integers.',
          'Все ограничения должны быть целыми числами.'));
      return;
    }
    final limits = ScanLimits(
      fileTimeoutSeconds: values['fileTimeout']!,
      maximumFileBytes: values['maximumFileBytes']!,
      maximumTotalBytes: values['maximumTotalBytes']!,
      maximumFiles: values['maximumFiles']!,
      maximumDepth: values['maximumDepth']!,
      oneFileSystem: oneFileSystem,
    );
    final updated = updateProfile(
      widget.profile,
      verificationMode: verificationMode,
      readErrorPolicy: readErrorPolicy,
      readRetryCount: values['retries']!,
      unstableRetryCount: values['unstableRetries']!,
      limits: limits,
      symlinkPolicy: symlinkPolicy,
      trustedBaselineManifest: _emptyToNull(baselineManifest.text),
      trustedBaselineSignature: _emptyToNull(baselineSignature.text),
      trustedPublicKey: _emptyToNull(trustedPublicKey.text),
      trustedSigner: _emptyToNull(trustedSigner.text),
      releaseCommit: _emptyToNull(releaseCommit.text),
      releaseBuild: _emptyToNull(releaseBuild.text),
    );
    final errors = updated.validate();
    if (errors.isNotEmpty) {
      setState(() => error = errors.join(' '));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSaved(updated);
    } on Object catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Widget _heading(String value) => Text(
        value,
        style: const TextStyle(
          color: _policyAccent,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _field(String label, TextEditingController controller) => Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(label, style: const TextStyle(color: _policyMuted)),
            TextField(controller: controller),
          ],
        ),
      );

  Widget _choice(
    String label,
    bool selected,
    VoidCallback onTap, {
    bool warning = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          color: selected ? _policySurfaceStrong : null,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            '${selected ? '●' : '○'} $label',
            maxLines: 1,
            style: TextStyle(
              color: selected
                  ? warning
                      ? _policyWarning
                      : _policyAccent
                  : _policyMuted,
            ),
          ),
        ),
      );

  Widget _toggle(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Text(
          '${selected ? '[✓]' : '[ ]'} $label',
          maxLines: 1,
          style: TextStyle(color: selected ? _policyText : _policyMuted),
        ),
      );

  Widget _button(String label, VoidCallback? onTap, {bool muted = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          color: onTap == null
              ? const Color(0x27313D)
              : muted
                  ? _policySurfaceStrong
                  : _policyAccent,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null
                  ? _policyMuted
                  : muted
                      ? _policyText
                      : _policyBackground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}
