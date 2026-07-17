import 'package:cinder/cinder.dart';

import '../core/docker_browser.dart';
import '../core/profile.dart';

const _accent = Color(0x64D8CB);
const _background = Color(0x0D1117);
const _surface = Color(0x151B23);
const _surfaceStrong = Color(0x1D2632);
const _muted = Color(0x7D8A99);
const _text = Color(0xE6EDF3);
const _danger = Color(0xF47067);

class DockerSourcePicker extends StatefulWidget {
  const DockerSourcePicker({
    super.key,
    required this.sourceType,
    required this.locale,
    required this.onSelected,
    required this.onCancel,
    this.dockerContext,
    this.composeFile,
    this.initialResource,
    this.initialPath = '/',
  });

  final SourceType sourceType;
  final String locale;
  final String? dockerContext;
  final String? composeFile;
  final String? initialResource;
  final String initialPath;
  final ValueChanged<DockerSourceSelection> onSelected;
  final VoidCallback onCancel;

  @override
  State<DockerSourcePicker> createState() => _DockerSourcePickerState();
}

class _DockerSourcePickerState extends State<DockerSourcePicker> {
  final focusNode = FocusNode(debugLabel: 'Centra Docker browser');
  final service = DockerBrowserService();

  List<DockerResource> resources = const <DockerResource>[];
  DockerBrowseSession? session;
  DockerDirectoryListing? listing;
  var selected = 0;
  var loading = false;
  String? error;

  DockerPickerStrings get strings => DockerPickerStrings(widget.locale);
  bool get browsing => session != null;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  @override
  void dispose() {
    session?.dispose();
    focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    await session?.dispose();
    session = null;
    listing = null;
    setState(() {
      loading = true;
      error = null;
      selected = 0;
    });
    try {
      final loaded = await service.listResources(
        widget.sourceType,
        dockerContext: widget.dockerContext,
        composeFile: widget.composeFile,
      );
      if (!mounted) return;
      setState(() {
        resources = loaded;
        final initialIndex = loaded.indexWhere(
          (resource) => resource.reference == widget.initialResource,
        );
        selected = initialIndex < 0 ? 0 : initialIndex;
        loading = false;
      });
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        loading = false;
      });
    }
  }

  Future<void> _openResource(DockerResource resource) async {
    await session?.dispose();
    session = null;
    listing = null;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final opened = await service.open(
        widget.sourceType,
        resource,
        dockerContext: widget.dockerContext,
        composeFile: widget.composeFile,
      );
      final initialPath = resource.reference == widget.initialResource
          ? widget.initialPath
          : '/';
      final firstListing = await opened.listDirectories(initialPath);
      if (!mounted) {
        await opened.dispose();
        return;
      }
      setState(() {
        session = opened;
        listing = firstListing;
        selected = 0;
        loading = false;
      });
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        loading = false;
      });
    }
  }

  Future<void> _loadDirectory(String path) async {
    final active = session;
    if (active == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await active.listDirectories(path);
      if (!mounted) return;
      setState(() {
        listing = next;
        selected = 0;
        loading = false;
      });
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        loading = false;
      });
    }
  }

  void _move(int delta) {
    final count = browsing ? listing?.entries.length ?? 0 : resources.length;
    if (count == 0) return;
    setState(() {
      selected = (selected + delta) % count;
      if (selected < 0) selected += count;
    });
  }

  Future<void> _activate() async {
    if (browsing) {
      final entries = listing?.entries ?? const <DockerDirectoryEntry>[];
      if (entries.isEmpty || selected >= entries.length) return;
      await _loadDirectory(entries[selected].path);
      return;
    }
    if (resources.isEmpty || selected >= resources.length) return;
    await _openResource(resources[selected]);
  }

  Future<void> _back() async {
    if (!browsing) {
      await _cancel();
      return;
    }
    final active = session;
    await active?.dispose();
    if (!mounted) return;
    setState(() {
      session = null;
      listing = null;
      selected = resources.indexWhere(
        (resource) => resource.reference == active?.resource.reference,
      );
      if (selected < 0) selected = 0;
      error = null;
    });
  }

  Future<void> _goParent() async {
    final parent = listing?.parentPath;
    if (parent != null) await _loadDirectory(parent);
  }

  Future<void> _choose() async {
    final active = session;
    final current = listing;
    if (active == null || current == null) return;
    final selection = DockerSourceSelection(
      sourceType: widget.sourceType,
      resource: active.resource,
      path: current.path,
    );
    await active.dispose();
    session = null;
    widget.onSelected(selection);
  }

  Future<void> _cancel() async {
    await session?.dispose();
    session = null;
    widget.onCancel();
  }

  bool _handleKey(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      _back();
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowUp) {
      _move(-1);
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowDown) {
      _move(1);
      return true;
    }
    if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.arrowRight) {
      _activate();
      return true;
    }
    if (event.logicalKey == LogicalKey.backspace ||
        event.logicalKey == LogicalKey.arrowLeft) {
      browsing ? _goParent() : _cancel();
      return true;
    }
    if (event.logicalKey == LogicalKey.space && browsing) {
      _choose();
      return true;
    }
    if (event.logicalKey == LogicalKey.keyR) {
      browsing ? _loadDirectory(listing?.path ?? '/') : _loadResources();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: SizedBox(
        width: 84,
        height: 26,
        child: Container(
          decoration: BoxDecoration(
            color: _background,
            border: BoxBorder.all(
              color: _accent,
              style: BoxBorderStyle.rounded,
            ),
            title: BorderTitle(
              text: strings.title(widget.sourceType),
              style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          padding: const EdgeInsets.all(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _summary(),
              const SizedBox(height: 1),
              Expanded(child: _body()),
              const SizedBox(height: 1),
              _actions(),
              Text(
                browsing ? strings.filesystemHelp : strings.resourceHelp,
                maxLines: 1,
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary() {
    if (!browsing) {
      return Text(
        strings.chooseResource(widget.sourceType),
        style: const TextStyle(color: _muted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          session!.resource.title,
          maxLines: 1,
          style: const TextStyle(color: _text, fontWeight: FontWeight.bold),
        ),
        Container(
          color: _surfaceStrong,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            listing?.path ?? '/',
            maxLines: 1,
            style: const TextStyle(color: _accent),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (loading) {
      return Center(
        child: Text(strings.loading, style: const TextStyle(color: _muted)),
      );
    }
    if (error != null) {
      return Center(
        child: Text(error!, style: const TextStyle(color: _danger)),
      );
    }
    if (!browsing) return _resourceList();
    return _directoryList();
  }

  Widget _resourceList() {
    if (resources.isEmpty) {
      return Center(
        child: Text(strings.noResources, style: const TextStyle(color: _muted)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: BoxBorder.all(
          color: const Color(0x27313D),
          style: BoxBorderStyle.rounded,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: resources
              .asMap()
              .entries
              .map((entry) {
                final focused = selected == entry.key;
                return GestureDetector(
                  onTap: () {
                    setState(() => selected = entry.key);
                    _openResource(entry.value);
                  },
                  child: Container(
                    color: focused ? _surfaceStrong : null,
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          '${focused ? '›' : ' '} ${entry.value.title}',
                          maxLines: 1,
                          style: TextStyle(
                            color: focused ? _accent : _text,
                            fontWeight: focused
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (entry.value.subtitle.isNotEmpty)
                          Text(
                            '  ${entry.value.subtitle}',
                            maxLines: 1,
                            style: const TextStyle(color: _muted),
                          ),
                      ],
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _directoryList() {
    final entries = listing?.entries ?? const <DockerDirectoryEntry>[];
    if (entries.isEmpty) {
      return Center(
        child: Text(strings.noFolders, style: const TextStyle(color: _muted)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: BoxBorder.all(
          color: const Color(0x27313D),
          style: BoxBorderStyle.rounded,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: entries
              .asMap()
              .entries
              .map((entry) {
                final focused = selected == entry.key;
                return GestureDetector(
                  onTap: () {
                    setState(() => selected = entry.key);
                    _loadDirectory(entry.value.path);
                  },
                  child: Container(
                    color: focused ? _surfaceStrong : null,
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      '${focused ? '›' : ' '} ${entry.value.isParent ? '↰' : '▸'} ${entry.value.name}',
                      maxLines: 1,
                      style: TextStyle(
                        color: focused ? _accent : _text,
                        fontWeight: focused
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: <Widget>[
        _PickerButton(
          label: strings.refresh,
          onTap: browsing
              ? () => _loadDirectory(listing?.path ?? '/')
              : _loadResources,
          muted: true,
        ),
        const Spacer(),
        _PickerButton(
          label: browsing ? strings.back : strings.cancel,
          onTap: _back,
          muted: true,
        ),
        if (browsing) ...<Widget>[
          const SizedBox(width: 1),
          _PickerButton(label: strings.choose, onTap: _choose),
        ],
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.label,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: muted ? _surfaceStrong : _accent,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          label,
          style: TextStyle(
            color: muted ? _text : _background,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class DockerPickerStrings {
  const DockerPickerStrings(this.locale);

  final String locale;

  Map<String, String> get _values =>
      _translations[locale] ?? _translations['en']!;

  String value(String key) => _values[key] ?? _translations['en']![key] ?? key;
  String get loading => value('loading');
  String get noResources => value('noResources');
  String get noFolders => value('noFolders');
  String get choose => value('choose');
  String get cancel => value('cancel');
  String get back => value('back');
  String get refresh => value('refresh');
  String get resourceHelp => value('resourceHelp');
  String get filesystemHelp => value('filesystemHelp');

  String title(SourceType type) => '${value('title')} · ${_typeName(type)}';
  String chooseResource(SourceType type) =>
      '${value('chooseResource')} ${_typeName(type)}';

  String _typeName(SourceType type) => switch (type) {
    SourceType.dockerContainer => value('container'),
    SourceType.dockerImage => value('image'),
    SourceType.dockerCompose => value('service'),
    SourceType.local => value('folder'),
    SourceType.ssh => value('remote'),
  };

  static const _translations = <String, Map<String, String>>{
    'en': <String, String>{
      'title': 'Docker filesystem',
      'chooseResource': 'Choose',
      'container': 'running container',
      'image': 'image',
      'service': 'Compose service',
      'folder': 'folder',
      'remote': 'remote source',
      'loading': 'Reading Docker…',
      'noResources': 'No matching Docker resources found.',
      'noFolders': 'No subfolders in this directory.',
      'choose': 'Use this folder',
      'cancel': 'Cancel',
      'back': 'Back to resources',
      'refresh': 'Refresh',
      'resourceHelp':
          '↑↓ move  Enter open  R refresh  Esc cancel  Mouse supported',
      'filesystemHelp':
          '↑↓ move  Enter open  Backspace parent  Space choose  Esc resources',
    },
    'ru': <String, String>{
      'title': 'Файловая система Docker',
      'chooseResource': 'Выберите',
      'container': 'запущенный контейнер',
      'image': 'образ',
      'service': 'Compose-сервис',
      'loading': 'Чтение Docker…',
      'noResources': 'Подходящие ресурсы Docker не найдены.',
      'noFolders': 'В этой папке нет вложенных папок.',
      'choose': 'Выбрать эту папку',
      'cancel': 'Отмена',
      'back': 'К списку ресурсов',
      'refresh': 'Обновить',
      'resourceHelp':
          '↑↓ выбор  Enter открыть  R обновить  Esc отмена  Мышь работает',
      'filesystemHelp':
          '↑↓ выбор  Enter открыть  Backspace вверх  Space выбрать  Esc к списку',
    },
    'uz': <String, String>{
      'title': 'Docker fayl tizimi',
      'chooseResource': 'Tanlang',
      'container': 'ishlayotgan konteyner',
      'image': 'obraz',
      'service': 'Compose xizmati',
      'loading': 'Docker o‘qilmoqda…',
      'noResources': 'Mos Docker resurslari topilmadi.',
      'noFolders': 'Ichki papkalar yo‘q.',
      'choose': 'Shu papkani tanlash',
      'cancel': 'Bekor qilish',
      'back': 'Resurslarga qaytish',
      'refresh': 'Yangilash',
      'resourceHelp': '↑↓ tanlash  Enter ochish  R yangilash  Esc bekor',
      'filesystemHelp':
          '↑↓ tanlash  Enter ochish  Backspace yuqori  Space tanlash',
    },
    'uz-Cyrl': <String, String>{
      'title': 'Docker файл тизими',
      'chooseResource': 'Танланг',
      'container': 'ишлаётган контейнер',
      'image': 'образ',
      'service': 'Compose хизмати',
      'loading': 'Docker ўқилмоқда…',
      'noResources': 'Мос Docker ресурслари топилмади.',
      'noFolders': 'Ички папкалар йўқ.',
      'choose': 'Шу папкани танлаш',
      'cancel': 'Бекор қилиш',
      'back': 'Ресурсларга қайтиш',
      'refresh': 'Янгилаш',
      'resourceHelp': '↑↓ танлаш  Enter очиш  R янгилаш  Esc бекор',
      'filesystemHelp': '↑↓ танлаш  Enter очиш  Backspace юқори  Space танлаш',
    },
    'tr': <String, String>{
      'title': 'Docker dosya sistemi',
      'chooseResource': 'Seçin',
      'container': 'çalışan konteyner',
      'image': 'imaj',
      'service': 'Compose servisi',
      'loading': 'Docker okunuyor…',
      'noResources': 'Uygun Docker kaynağı bulunamadı.',
      'noFolders': 'Alt klasör yok.',
      'choose': 'Bu klasörü kullan',
      'cancel': 'İptal',
      'back': 'Kaynaklara dön',
      'refresh': 'Yenile',
      'resourceHelp': '↑↓ seç  Enter aç  R yenile  Esc iptal',
      'filesystemHelp': '↑↓ seç  Enter aç  Backspace üst  Space kullan',
    },
    'kk': <String, String>{
      'title': 'Docker файл жүйесі',
      'chooseResource': 'Таңдаңыз',
      'container': 'іске қосылған контейнер',
      'image': 'образ',
      'service': 'Compose қызметі',
      'loading': 'Docker оқылуда…',
      'noResources': 'Docker ресурстары табылмады.',
      'noFolders': 'Ішкі қалталар жоқ.',
      'choose': 'Осы қалтаны таңдау',
      'cancel': 'Бас тарту',
      'back': 'Ресурстарға оралу',
      'refresh': 'Жаңарту',
      'resourceHelp': '↑↓ таңдау  Enter ашу  R жаңарту  Esc бас тарту',
      'filesystemHelp': '↑↓ таңдау  Enter ашу  Backspace жоғары  Space таңдау',
    },
    'ky': <String, String>{
      'title': 'Docker файл тутуму',
      'chooseResource': 'Тандаңыз',
      'container': 'иштеп жаткан контейнер',
      'image': 'образ',
      'service': 'Compose кызматы',
      'loading': 'Docker окулууда…',
      'noResources': 'Docker ресурстары табылган жок.',
      'noFolders': 'Ички папкалар жок.',
      'choose': 'Бул папканы тандоо',
      'cancel': 'Жокко чыгаруу',
      'back': 'Ресурстарга кайтуу',
      'refresh': 'Жаңыртуу',
      'resourceHelp': '↑↓ тандоо  Enter ачуу  R жаңыртуу  Esc жокко чыгаруу',
      'filesystemHelp': '↑↓ тандоо  Enter ачуу  Backspace өйдө  Space тандоо',
    },
    'tg': <String, String>{
      'title': 'Системаи файлии Docker',
      'chooseResource': 'Интихоб кунед',
      'container': 'контейнери фаъол',
      'image': 'образ',
      'service': 'хидмати Compose',
      'loading': 'Docker хонда мешавад…',
      'noResources': 'Захираҳои Docker ёфт нашуданд.',
      'noFolders': 'Зерҷузвдон нест.',
      'choose': 'Ин ҷузвдонро интихоб кунед',
      'cancel': 'Бекор кардан',
      'back': 'Бозгашт ба захираҳо',
      'refresh': 'Навсозӣ',
      'resourceHelp': '↑↓ интихоб  Enter кушодан  R навсозӣ  Esc бекор',
      'filesystemHelp':
          '↑↓ интихоб  Enter кушодан  Backspace боло  Space интихоб',
    },
    'az': <String, String>{
      'title': 'Docker fayl sistemi',
      'chooseResource': 'Seçin',
      'container': 'işləyən konteyner',
      'image': 'obraz',
      'service': 'Compose xidməti',
      'loading': 'Docker oxunur…',
      'noResources': 'Docker resursu tapılmadı.',
      'noFolders': 'Alt qovluq yoxdur.',
      'choose': 'Bu qovluğu seçin',
      'cancel': 'Ləğv et',
      'back': 'Resurslara qayıt',
      'refresh': 'Yenilə',
      'resourceHelp': '↑↓ seçim  Enter aç  R yenilə  Esc ləğv',
      'filesystemHelp': '↑↓ seçim  Enter aç  Backspace yuxarı  Space seç',
    },
    'de': <String, String>{
      'title': 'Docker-Dateisystem',
      'chooseResource': 'Auswählen',
      'container': 'laufenden Container',
      'image': 'Image',
      'service': 'Compose-Dienst',
      'loading': 'Docker wird gelesen…',
      'noResources': 'Keine passenden Docker-Ressourcen gefunden.',
      'noFolders': 'Keine Unterordner vorhanden.',
      'choose': 'Diesen Ordner verwenden',
      'cancel': 'Abbrechen',
      'back': 'Zurück zu Ressourcen',
      'refresh': 'Aktualisieren',
      'resourceHelp': '↑↓ wählen  Enter öffnen  R aktualisieren  Esc abbrechen',
      'filesystemHelp':
          '↑↓ wählen  Enter öffnen  Backspace hoch  Space verwenden',
    },
  };
}
