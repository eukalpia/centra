from pathlib import Path

path = Path('lib/src/tui/centra_app.dart')
text = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Expected one match, found {count}: {old[:80]!r}')
    text = text.replace(old, new, 1)


replace_once(
    "import '../core/algorithm_registry.dart';\n",
    "import '../core/algorithm_registry.dart';\n"
    "import '../core/docker_browser.dart';\n",
)
replace_once(
    "import 'folder_picker.dart';\nimport 'wizard_state.dart';\n",
    "import 'docker_source_picker.dart';\n"
    "import 'folder_picker.dart';\n"
    "import 'wizard_state.dart';\n",
)
replace_once(
    "  TextEditingController? folderPickerController;\n"
    "  FocusNode? folderPickerReturnFocus;\n",
    "  TextEditingController? folderPickerController;\n"
    "  FocusNode? folderPickerReturnFocus;\n"
    "  SourceType? dockerPickerSourceType;\n"
    "  String? selectedDockerResourceTitle;\n",
)
replace_once(
    "  void _selectFolder(String path) {\n"
    "    final controller = folderPickerController;\n"
    "    final returnFocus = folderPickerReturnFocus;\n"
    "    if (controller != null) controller.text = path;\n"
    "    _syncDraft();\n"
    "    setState(() {\n"
    "      error = null;\n"
    "      folderPickerController = null;\n"
    "      folderPickerReturnFocus = null;\n"
    "    });\n"
    "    returnFocus?.requestFocus();\n"
    "  }\n",
    "  void _selectFolder(String path) {\n"
    "    final controller = folderPickerController;\n"
    "    final returnFocus = folderPickerReturnFocus;\n"
    "    if (controller != null) controller.text = path;\n"
    "    _syncDraft();\n"
    "    setState(() {\n"
    "      error = null;\n"
    "      folderPickerController = null;\n"
    "      folderPickerReturnFocus = null;\n"
    "    });\n"
    "    returnFocus?.requestFocus();\n"
    "  }\n\n"
    "  String? _selectedDockerReference(SourceType sourceType) =>\n"
    "      switch (sourceType) {\n"
    "        SourceType.dockerContainer => container.text.trim(),\n"
    "        SourceType.dockerImage => image.text.trim(),\n"
    "        SourceType.dockerCompose => service.text.trim(),\n"
    "        SourceType.local || SourceType.ssh => null,\n"
    "      };\n\n"
    "  void _openDockerPicker() {\n"
    "    _syncDraft();\n"
    "    final sourceType = draft.sourceType;\n"
    "    if (sourceType != SourceType.dockerContainer &&\n"
    "        sourceType != SourceType.dockerImage &&\n"
    "        sourceType != SourceType.dockerCompose) {\n"
    "      return;\n"
    "    }\n"
    "    setState(() {\n"
    "      error = null;\n"
    "      dockerPickerSourceType = sourceType;\n"
    "    });\n"
    "  }\n\n"
    "  void _closeDockerPicker() {\n"
    "    setState(() => dockerPickerSourceType = null);\n"
    "    wizardFocus.requestFocus();\n"
    "  }\n\n"
    "  void _selectDockerSource(DockerSourceSelection selection) {\n"
    "    root.text = selection.path;\n"
    "    switch (selection.sourceType) {\n"
    "      case SourceType.dockerContainer:\n"
    "        container.text = selection.resource.reference;\n"
    "        break;\n"
    "      case SourceType.dockerImage:\n"
    "        image.text = selection.resource.reference;\n"
    "        break;\n"
    "      case SourceType.dockerCompose:\n"
    "        service.text = selection.resource.reference;\n"
    "        break;\n"
    "      case SourceType.local:\n"
    "      case SourceType.ssh:\n"
    "        return;\n"
    "    }\n"
    "    selectedDockerResourceTitle = selection.resource.title;\n"
    "    _syncDraft();\n"
    "    setState(() {\n"
    "      error = null;\n"
    "      dockerPickerSourceType = null;\n"
    "    });\n"
    "    wizardFocus.requestFocus();\n"
    "  }\n",
)
replace_once(
    "    if (folderPickerController != null) return false;\n",
    "    if (folderPickerController != null || dockerPickerSourceType != null) {\n"
    "      return false;\n"
    "    }\n",
)
replace_once(
    "        case WizardStep.source:\n"
    "          draft.sourceType = items[index] as SourceType;\n"
    "          break;\n",
    "        case WizardStep.source:\n"
    "          final nextSource = items[index] as SourceType;\n"
    "          if (draft.sourceType != nextSource) {\n"
    "            root.clear();\n"
    "            container.clear();\n"
    "            image.clear();\n"
    "            service.clear();\n"
    "            selectedDockerResourceTitle = null;\n"
    "          }\n"
    "          draft.sourceType = nextSource;\n"
    "          break;\n",
)
replace_once(
    "    final pickerController = folderPickerController;\n"
    "    if (pickerController == null) return screen;\n\n"
    "    return Stack(\n"
    "      children: <Widget>[\n"
    "        screen,\n"
    "        ModalBarrier(\n"
    "          color: const Color(0x000000).withAlpha(196),\n"
    "          obscure: false,\n"
    "          onDismiss: _closeFolderPicker,\n"
    "        ),\n"
    "        Center(\n"
    "          child: FolderPicker(\n"
    "            initialPath: pickerController.text,\n"
    "            locale: locale,\n"
    "            onSelected: _selectFolder,\n"
    "            onCancel: _closeFolderPicker,\n"
    "          ),\n"
    "        ),\n"
    "      ],\n"
    "    );\n",
    "    final dockerSourceType = dockerPickerSourceType;\n"
    "    if (dockerSourceType != null) {\n"
    "      return Stack(\n"
    "        children: <Widget>[\n"
    "          screen,\n"
    "          ModalBarrier(\n"
    "            color: const Color(0x000000).withAlpha(196),\n"
    "            obscure: false,\n"
    "            onDismiss: _closeDockerPicker,\n"
    "          ),\n"
    "          Center(\n"
    "            child: DockerSourcePicker(\n"
    "              sourceType: dockerSourceType,\n"
    "              locale: locale,\n"
    "              dockerContext: dockerContext.text.trim(),\n"
    "              composeFile: composeFile.text.trim(),\n"
    "              initialResource: _selectedDockerReference(dockerSourceType),\n"
    "              initialPath:\n"
    "                  root.text.trim().isEmpty ? '/' : root.text.trim(),\n"
    "              onSelected: _selectDockerSource,\n"
    "              onCancel: _closeDockerPicker,\n"
    "            ),\n"
    "          ),\n"
    "        ],\n"
    "      );\n"
    "    }\n\n"
    "    final pickerController = folderPickerController;\n"
    "    if (pickerController == null) return screen;\n\n"
    "    return Stack(\n"
    "      children: <Widget>[\n"
    "        screen,\n"
    "        ModalBarrier(\n"
    "          color: const Color(0x000000).withAlpha(196),\n"
    "          obscure: false,\n"
    "          onDismiss: _closeFolderPicker,\n"
    "        ),\n"
    "        Center(\n"
    "          child: FolderPicker(\n"
    "            initialPath: pickerController.text,\n"
    "            locale: locale,\n"
    "            onSelected: _selectFolder,\n"
    "            onCancel: _closeFolderPicker,\n"
    "          ),\n"
    "        ),\n"
    "      ],\n"
    "    );\n",
)
old_details = """  Widget _detailsStep() {
    final fields = <Widget>[
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
    switch (draft.sourceType) {
      case SourceType.ssh:
        fields.addAll(<Widget>[
          _field(strings('host'), host, hostFocus, 'server.example.com'),
          _field(strings('user'), user, userFocus, 'deploy'),
          _field(strings('port'), port, portFocus, '22'),
          _field(
            strings('identityFile'),
            identityFile,
            identityFileFocus,
            '~/.ssh/id_ed25519',
          ),
        ]);
        break;
      case SourceType.dockerContainer:
        fields.addAll(<Widget>[
          _field(
            strings('container'),
            container,
            containerFocus,
            'application-1',
          ),
          _field(
            strings('dockerContext'),
            dockerContext,
            dockerContextFocus,
            'default',
          ),
        ]);
        break;
      case SourceType.dockerImage:
        fields.addAll(<Widget>[
          _field(
            strings('image'),
            image,
            imageFocus,
            'registry.example.com/application:1.0.0',
          ),
          _field(
            strings('dockerContext'),
            dockerContext,
            dockerContextFocus,
            'default',
          ),
        ]);
        break;
      case SourceType.dockerCompose:
        fields.addAll(<Widget>[
          _field(strings('service'), service, serviceFocus, 'api'),
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
        ]);
        break;
      case SourceType.local:
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
"""
new_details = """  Widget _detailsStep() {
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
        fields.addAll(<Widget>[
          _field(strings('rootPath'), root, rootFocus, '/srv/application'),
          _field(strings('host'), host, hostFocus, 'server.example.com'),
          _field(strings('user'), user, userFocus, 'deploy'),
          _field(strings('port'), port, portFocus, '22'),
          _field(
            strings('identityFile'),
            identityFile,
            identityFileFocus,
            '~/.ssh/id_ed25519',
          ),
        ]);
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
            hasSelection
                ? (selectedDockerResourceTitle ?? reference)
                : '—',
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
"""
replace_once(old_details, new_details)

path.write_text(text, encoding='utf-8')
