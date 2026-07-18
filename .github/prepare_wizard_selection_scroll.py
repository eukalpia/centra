from pathlib import Path
import re


path = Path('lib/src/tui/centra_app.dart')
text = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str) -> None:
    global text
    if old not in text:
        raise SystemExit(f'Pattern not found: {old[:180]!r}')
    text = text.replace(old, new, 1)


def replace_regex(pattern: str, replacement: str) -> None:
    global text
    text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'Regex matched {count} times: {pattern[:180]!r}')


replace_once(
    "  final wizardFocus = FocusNode(debugLabel: 'Centra wizard');\n",
    "  final wizardFocus = FocusNode(debugLabel: 'Centra wizard');\n"
    "  final wizardScroll = ScrollController();\n",
)

replace_once(
    "    for (final focusNode in <FocusNode>[wizardFocus, ..._textFieldFocusNodes]) {\n"
    "      focusNode.dispose();\n"
    "    }\n"
    "    super.dispose();",
    "    for (final focusNode in <FocusNode>[wizardFocus, ..._textFieldFocusNodes]) {\n"
    "      focusNode.dispose();\n"
    "    }\n"
    "    wizardScroll.dispose();\n"
    "    super.dispose();",
)

items_getter = """  List<Object> get _itemsForStep => switch (step) {
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
"""

navigation_helpers = items_getter + """

  bool get _stepUsesWizardList => switch (step) {
        WizardStep.language ||
        WizardStep.source ||
        WizardStep.algorithms ||
        WizardStep.exclusions ||
        WizardStep.output => true,
        WizardStep.details || WizardStep.review => false,
      };

  int get _wizardListLeadingItems => switch (step) {
        WizardStep.language || WizardStep.source || WizardStep.algorithms => 2,
        WizardStep.exclusions => 7,
        WizardStep.output => 3,
        WizardStep.details || WizardStep.review => 0,
      };

  void _ensureCursorVisible() {
    if (!_stepUsesWizardList) return;
    final listIndex = _wizardListLeadingItems + cursor;

    void ensure() => wizardScroll.ensureIndexVisible(index: listIndex);

    try {
      TerminalBinding.instance.addPostFrameCallback((_) => ensure());
    } on Object {
      ensure();
    }
  }

  void _resetWizardScroll() {
    void reset() => wizardScroll.scrollToStart();

    try {
      TerminalBinding.instance.addPostFrameCallback((_) => reset());
    } on Object {
      reset();
    }
  }

  void _moveCursor(int delta, int itemCount) {
    if (itemCount <= 0) return;
    setState(() {
      cursor = (cursor + delta) % itemCount;
      if (cursor < 0) cursor += itemCount;
    });
    _ensureCursorVisible();
  }

  void _jumpCursor(int index, int itemCount) {
    if (itemCount <= 0) return;
    setState(() => cursor = index.clamp(0, itemCount - 1));
    _ensureCursorVisible();
  }

  int _visibleOptionCount() {
    final viewport = wizardScroll.viewportDimension;
    if (viewport <= 2) return 5;
    final visible = (viewport / 2).floor();
    return visible > 0 ? visible : 1;
  }
"""
replace_once(items_getter, navigation_helpers)

old_keys = """    final items = _itemsForStep;
    if (items.isNotEmpty && event.logicalKey == LogicalKey.arrowUp) {
      setState(() => cursor = cursor <= 0 ? items.length - 1 : cursor - 1);
      return true;
    }
    if (items.isNotEmpty && event.logicalKey == LogicalKey.arrowDown) {
      setState(() => cursor = (cursor + 1) % items.length);
      return true;
    }
"""
new_keys = """    final items = _itemsForStep;
    if (items.isNotEmpty && event.logicalKey == LogicalKey.arrowUp) {
      _moveCursor(-1, items.length);
      return true;
    }
    if (items.isNotEmpty && event.logicalKey == LogicalKey.arrowDown) {
      _moveCursor(1, items.length);
      return true;
    }
    if (items.isNotEmpty && event.logicalKey == LogicalKey.pageUp) {
      _moveCursor(-_visibleOptionCount(), items.length);
      return true;
    }
    if (items.isNotEmpty && event.logicalKey == LogicalKey.pageDown) {
      _moveCursor(_visibleOptionCount(), items.length);
      return true;
    }
    if (items.isNotEmpty && event.logicalKey == LogicalKey.home) {
      _jumpCursor(0, items.length);
      return true;
    }
    if (items.isNotEmpty && event.logicalKey == LogicalKey.end) {
      _jumpCursor(items.length - 1, items.length);
      return true;
    }
"""
replace_once(old_keys, new_keys)

replace_once(
    "    });\n    if (continueAfter) _next();\n  }\n\n  Future<void> _prepareExclusions()",
    "    });\n"
    "    if (continueAfter) {\n"
    "      _next();\n"
    "    } else {\n"
    "      _ensureCursorVisible();\n"
    "    }\n"
    "  }\n\n"
    "  Future<void> _prepareExclusions()",
)

replace_once(
    "    if (!_stepHasTextField(nextStep)) wizardFocus.requestFocus();\n  }",
    "    _resetWizardScroll();\n"
    "    if (!_stepHasTextField(nextStep)) wizardFocus.requestFocus();\n"
    "  }",
)

replace_once(
    "    if (!_stepHasTextField(previousStep)) wizardFocus.requestFocus();\n  }",
    "    _resetWizardScroll();\n"
    "    if (!_stepHasTextField(previousStep)) wizardFocus.requestFocus();\n"
    "  }",
)

replace_once(
    "                if (!_stepHasTextField(candidate)) {\n"
    "                  wizardFocus.requestFocus();\n"
    "                }",
    "                _resetWizardScroll();\n"
    "                if (!_stepHasTextField(candidate)) {\n"
    "                  wizardFocus.requestFocus();\n"
    "                }",
)

replace_once(
    "          Expanded(child: SingleChildScrollView(child: body)),",
    "          Expanded(\n"
    "            child: _stepUsesWizardList\n"
    "                ? body\n"
    "                : SingleChildScrollView(child: body),\n"
    "          ),",
)

replace_regex(
    r"  Widget _languageStep\(\) => Column\(.*?\n      \);\n\n  Widget _sourceStep\(\) \{",
    """  Widget _languageStep() => ListView(
        controller: wizardScroll,
        children: <Widget>[
          _SectionTitle(
            strings('chooseLanguage'),
            strings('noAlgorithmDefault'),
          ),
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

  Widget _sourceStep() {""",
)

replace_regex(
    r"    return Column\(\n      crossAxisAlignment: CrossAxisAlignment\.stretch,\n      children: <Widget>\[\n        _SectionTitle\(\n          strings\('chooseSource'\),.*?\n      \],\n    \);\n  \}\n\n  Widget _detailsStep",
    """    return ListView(
      controller: wizardScroll,
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

  Widget _detailsStep""",
)

replace_regex(
    r"  Widget _algorithmStep\(\) => Column\(.*?\n      \);\n\n  Widget _exclusionStep",
    """  Widget _algorithmStep() => ListView(
        controller: wizardScroll,
        children: <Widget>[
          _SectionTitle(
            strings('chooseAlgorithms'),
            strings('noAlgorithmDefault'),
          ),
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

  Widget _exclusionStep""",
)

replace_once(
    "  Widget _exclusionStep() => Column(\n",
    "  Widget _exclusionStep() => ListView(\n"
    "        controller: wizardScroll,\n",
)

replace_once(
    "    return Column(\n      crossAxisAlignment: CrossAxisAlignment.stretch,\n      children: <Widget>[\n        _SectionTitle(strings('output'), strings('outputHelp')),
",
    "    return ListView(\n"
    "      controller: wizardScroll,\n"
    "      children: <Widget>[\n"
    "        _SectionTitle(strings('output'), strings('outputHelp')),\n",
)

path.write_text(text, encoding='utf-8')
