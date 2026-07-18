import 'package:cinder/cinder.dart';

import '../core/scan_control.dart';
import '../core/storage.dart';
import '../i18n/messages.dart';

const _settingsAccent = Color(0x64D8CB);
const _settingsBackground = Color(0x0D1117);
const _settingsSurface = Color(0x151B23);
const _settingsSurfaceStrong = Color(0x1D2632);
const _settingsMuted = Color(0x7D8A99);
const _settingsText = Color(0xE6EDF3);

class CentraSettingsPanel extends StatefulWidget {
  const CentraSettingsPanel({
    super.key,
    required this.settings,
    required this.onSaved,
    required this.onCancel,
  });

  final CentraSettings settings;
  final Future<void> Function(CentraSettings settings) onSaved;
  final VoidCallback onCancel;

  @override
  State<CentraSettingsPanel> createState() => _CentraSettingsPanelState();
}

class _CentraSettingsPanelState extends State<CentraSettingsPanel> {
  late String locale;
  late String theme;
  late bool confirmDestructiveActions;
  late bool confirmBeforeRootScan;
  late VerificationMode verificationMode;
  var saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    locale = widget.settings.locale;
    theme = widget.settings.theme;
    confirmDestructiveActions = widget.settings.confirmDestructiveActions;
    confirmBeforeRootScan = widget.settings.confirmBeforeRootScan;
    verificationMode = widget.settings.defaultVerificationMode;
  }

  @override
  Widget build(BuildContext context) {
    final strings = CentraStrings(locale);
    return SizedBox(
      width: 78,
      height: 30,
      child: Container(
        decoration: BoxDecoration(
          color: _settingsBackground,
          border: BoxBorder.all(
            color: _settingsAccent,
            style: BoxBorderStyle.rounded,
          ),
          title: BorderTitle(
            text: strings('settings'),
            style: const TextStyle(
              color: _settingsAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(strings('language'),
                style: const TextStyle(color: _settingsMuted)),
            Wrap(
              spacing: 1,
              children: CentraStrings.locales
                  .map(
                    (value) => _choice(
                      value.nativeName,
                      locale == value.code,
                      () => setState(() => locale = value.code),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 1),
            Text(strings('theme'),
                style: const TextStyle(color: _settingsMuted)),
            Row(
              children: <Widget>[
                Expanded(
                  child: _choice('Auto', theme == 'auto', () {
                    setState(() => theme = 'auto');
                  }),
                ),
                const SizedBox(width: 1),
                Expanded(
                  child: _choice('Dark', theme == 'dark', () {
                    setState(() => theme = 'dark');
                  }),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              strings('defaultVerificationMode'),
              style: const TextStyle(color: _settingsMuted),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: _choice(
                    strings('fullVerification'),
                    verificationMode == VerificationMode.full,
                    () => setState(
                      () => verificationMode = VerificationMode.full,
                    ),
                  ),
                ),
                const SizedBox(width: 1),
                Expanded(
                  child: _choice(
                    strings('fastVerification'),
                    verificationMode == VerificationMode.fast,
                    () => setState(
                      () => verificationMode = VerificationMode.fast,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            _toggle(
              strings('confirmRootScan'),
              confirmBeforeRootScan,
              () => setState(
                () => confirmBeforeRootScan = !confirmBeforeRootScan,
              ),
            ),
            _toggle(
              strings('confirmDestructiveActions'),
              confirmDestructiveActions,
              () => setState(
                () => confirmDestructiveActions = !confirmDestructiveActions,
              ),
            ),
            const Spacer(),
            if (error != null)
              Text(error!, style: const TextStyle(color: Color(0xF47067))),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                _button(strings('cancel'), widget.onCancel, muted: true),
                const SizedBox(width: 1),
                _button(
                  saving ? '${strings('save')}…' : strings('save'),
                  saving ? null : _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSaved(
        widget.settings.copyWith(
          locale: locale,
          theme: theme,
          confirmDestructiveActions: confirmDestructiveActions,
          confirmBeforeRootScan: confirmBeforeRootScan,
          defaultVerificationMode: verificationMode,
          onboardingCompleted: true,
        ),
      );
    } on Object catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          color: selected ? _settingsSurfaceStrong : _settingsSurface,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            '${selected ? '●' : '○'} $label',
            maxLines: 1,
            style: TextStyle(
              color: selected ? _settingsAccent : _settingsMuted,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );

  Widget _toggle(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          color: _settingsSurface,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            '${selected ? '[✓]' : '[ ]'} $label',
            style: TextStyle(
              color: selected ? _settingsText : _settingsMuted,
            ),
          ),
        ),
      );

  Widget _button(String label, VoidCallback? onTap, {bool muted = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          color: onTap == null
              ? const Color(0x27313D)
              : muted
                  ? _settingsSurfaceStrong
                  : _settingsAccent,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null
                  ? _settingsMuted
                  : muted
                      ? _settingsText
                      : _settingsBackground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}
