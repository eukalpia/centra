import 'dart:io';

import 'package:cinder/cinder.dart';
import 'package:path/path.dart' as p;

const _pickerAccent = Color(0x64D8CB);
const _pickerBackground = Color(0x0D1117);
const _pickerSurface = Color(0x151B23);
const _pickerSurfaceStrong = Color(0x1D2632);
const _pickerMuted = Color(0x7D8A99);
const _pickerText = Color(0xE6EDF3);
const _pickerDanger = Color(0xF47067);

class FolderPickerStrings {
  const FolderPickerStrings._(this.locale, this._values);

  final String locale;
  final Map<String, String> _values;

  String get browse => _value('browse');
  String get title => _value('title');
  String get currentFolder => _value('currentFolder');
  String get choose => _value('choose');
  String get cancel => _value('cancel');
  String get showHidden => _value('showHidden');
  String get hideHidden => _value('hideHidden');
  String get empty => _value('empty');
  String get loading => _value('loading');
  String get home => _value('home');
  String get roots => _value('roots');
  String get refresh => _value('refresh');
  String get help => _value('help');

  String _value(String key) => _values[key] ?? _translations['en']![key] ?? key;

  factory FolderPickerStrings.forLocale(String locale) {
    return FolderPickerStrings._(
      locale,
      _translations[locale] ?? _translations['en']!,
    );
  }

  static const _translations = <String, Map<String, String>>{
    'en': <String, String>{
      'browse': 'Browse…',
      'title': 'Choose folder',
      'currentFolder': 'Current folder',
      'choose': 'Use this folder',
      'cancel': 'Cancel',
      'showHidden': 'Show hidden',
      'hideHidden': 'Hide hidden',
      'empty': 'No subfolders',
      'loading': 'Reading folders…',
      'home': 'Home',
      'roots': 'Locations',
      'refresh': 'Refresh',
      'help':
          '↑↓ move  Enter open  Backspace parent  Space choose  H hidden  Esc cancel',
    },
    'ru': <String, String>{
      'browse': 'Обзор…',
      'title': 'Выбор папки',
      'currentFolder': 'Текущая папка',
      'choose': 'Выбрать эту папку',
      'cancel': 'Отмена',
      'showHidden': 'Показать скрытые',
      'hideHidden': 'Скрыть скрытые',
      'empty': 'Вложенных папок нет',
      'loading': 'Чтение папок…',
      'home': 'Домашняя',
      'roots': 'Расположения',
      'refresh': 'Обновить',
      'help':
          '↑↓ выбор  Enter открыть  Backspace вверх  Space выбрать  H скрытые  Esc отмена',
    },
    'uz': <String, String>{
      'browse': 'Ko‘rish…',
      'title': 'Papkani tanlash',
      'currentFolder': 'Joriy papka',
      'choose': 'Shu papkani tanlash',
      'cancel': 'Bekor qilish',
      'showHidden': 'Yashirinlarni ko‘rsatish',
      'hideHidden': 'Yashirinlarni berkitish',
      'empty': 'Ichki papkalar yo‘q',
      'loading': 'Papkalar o‘qilmoqda…',
      'home': 'Bosh papka',
      'roots': 'Joylashuvlar',
      'refresh': 'Yangilash',
      'help':
          '↑↓ tanlash  Enter ochish  Backspace yuqoriga  Space tanlash  H yashirin  Esc bekor',
    },
    'uz-Cyrl': <String, String>{
      'browse': 'Кўриш…',
      'title': 'Папкани танлаш',
      'currentFolder': 'Жорий папка',
      'choose': 'Шу папкани танлаш',
      'cancel': 'Бекор қилиш',
      'showHidden': 'Яширинларни кўрсатиш',
      'hideHidden': 'Яширинларни беркитиш',
      'empty': 'Ички папкалар йўқ',
      'loading': 'Папкалар ўқилмоқда…',
      'home': 'Бош папка',
      'roots': 'Жойлашувлар',
      'refresh': 'Янгилаш',
      'help':
          '↑↓ танлаш  Enter очиш  Backspace юқорига  Space танлаш  H яширин  Esc бекор',
    },
    'tr': <String, String>{
      'browse': 'Gözat…',
      'title': 'Klasör seç',
      'currentFolder': 'Geçerli klasör',
      'choose': 'Bu klasörü kullan',
      'cancel': 'İptal',
      'showHidden': 'Gizlileri göster',
      'hideHidden': 'Gizlileri gizle',
      'empty': 'Alt klasör yok',
      'loading': 'Klasörler okunuyor…',
      'home': 'Ana klasör',
      'roots': 'Konumlar',
      'refresh': 'Yenile',
      'help':
          '↑↓ seç  Enter aç  Backspace üst  Space kullan  H gizli  Esc iptal',
    },
    'kk': <String, String>{
      'browse': 'Шолу…',
      'title': 'Қалтаны таңдау',
      'currentFolder': 'Ағымдағы қалта',
      'choose': 'Осы қалтаны таңдау',
      'cancel': 'Бас тарту',
      'showHidden': 'Жасырынды көрсету',
      'hideHidden': 'Жасырынды жасыру',
      'empty': 'Ішкі қалталар жоқ',
      'loading': 'Қалталар оқылуда…',
      'home': 'Үй қалтасы',
      'roots': 'Орындар',
      'refresh': 'Жаңарту',
      'help':
          '↑↓ таңдау  Enter ашу  Backspace жоғары  Space таңдау  H жасырын  Esc бас тарту',
    },
    'ky': <String, String>{
      'browse': 'Кароо…',
      'title': 'Папканы тандоо',
      'currentFolder': 'Учурдагы папка',
      'choose': 'Бул папканы тандоо',
      'cancel': 'Жокко чыгаруу',
      'showHidden': 'Жашыруунду көрсөтүү',
      'hideHidden': 'Жашыруунду жашыруу',
      'empty': 'Ички папкалар жок',
      'loading': 'Папкалар окулууда…',
      'home': 'Үй папкасы',
      'roots': 'Жайлар',
      'refresh': 'Жаңыртуу',
      'help':
          '↑↓ тандоо  Enter ачуу  Backspace өйдө  Space тандоо  H жашыруун  Esc жокко чыгаруу',
    },
    'tg': <String, String>{
      'browse': 'Дидан…',
      'title': 'Интихоби ҷузвдон',
      'currentFolder': 'Ҷузвдони ҷорӣ',
      'choose': 'Ин ҷузвдонро интихоб кунед',
      'cancel': 'Бекор кардан',
      'showHidden': 'Намоиши пинҳонӣ',
      'hideHidden': 'Пинҳон кардани пинҳонӣ',
      'empty': 'Зерҷузвдон нест',
      'loading': 'Хондани ҷузвдонҳо…',
      'home': 'Ҷузвдони хонагӣ',
      'roots': 'Ҷойҳо',
      'refresh': 'Навсозӣ',
      'help':
          '↑↓ интихоб  Enter кушодан  Backspace боло  Space интихоб  H пинҳонӣ  Esc бекор',
    },
    'az': <String, String>{
      'browse': 'Baxış…',
      'title': 'Qovluq seçin',
      'currentFolder': 'Cari qovluq',
      'choose': 'Bu qovluğu seçin',
      'cancel': 'Ləğv et',
      'showHidden': 'Gizliləri göstər',
      'hideHidden': 'Gizliləri gizlət',
      'empty': 'Alt qovluq yoxdur',
      'loading': 'Qovluqlar oxunur…',
      'home': 'Ev qovluğu',
      'roots': 'Məkanlar',
      'refresh': 'Yenilə',
      'help':
          '↑↓ seçim  Enter aç  Backspace yuxarı  Space seç  H gizli  Esc ləğv',
    },
    'de': <String, String>{
      'browse': 'Durchsuchen…',
      'title': 'Ordner auswählen',
      'currentFolder': 'Aktueller Ordner',
      'choose': 'Diesen Ordner verwenden',
      'cancel': 'Abbrechen',
      'showHidden': 'Versteckte anzeigen',
      'hideHidden': 'Versteckte ausblenden',
      'empty': 'Keine Unterordner',
      'loading': 'Ordner werden gelesen…',
      'home': 'Persönlicher Ordner',
      'roots': 'Orte',
      'refresh': 'Aktualisieren',
      'help':
          '↑↓ wählen  Enter öffnen  Backspace hoch  Space verwenden  H versteckt  Esc abbrechen',
    },
  };
}

class FolderBrowserEntry {
  const FolderBrowserEntry({
    required this.name,
    required this.path,
    required this.isParent,
  });

  final String name;
  final String path;
  final bool isParent;
}

class FolderBrowserSnapshot {
  const FolderBrowserSnapshot({
    required this.path,
    required this.entries,
    required this.parentPath,
  });

  final String path;
  final List<FolderBrowserEntry> entries;
  final String? parentPath;
}

class FolderBrowserShortcut {
  const FolderBrowserShortcut(this.label, this.path);

  final String label;
  final String path;
}

class FolderBrowser {
  const FolderBrowser._();

  static String nearestExisting(String? candidate) {
    var path = candidate?.trim() ?? '';
    if (path.isEmpty) path = Directory.current.path;

    var current = Directory(p.normalize(p.absolute(path)));
    if (current.existsSync()) return current.path;

    final file = File(current.path);
    if (file.existsSync()) current = file.parent;

    while (!current.existsSync()) {
      final parent = current.parent;
      if (_samePath(parent.path, current.path)) {
        return Directory.current.path;
      }
      current = parent;
    }
    return current.path;
  }

  static Future<FolderBrowserSnapshot> read(
    String path, {
    bool showHidden = false,
  }) async {
    final resolved = nearestExisting(path);
    final directory = Directory(resolved);
    final entries = <FolderBrowserEntry>[];

    final parent = directory.parent;
    final parentPath = _samePath(parent.path, directory.path)
        ? null
        : p.normalize(parent.path);
    if (parentPath != null) {
      entries.add(
        FolderBrowserEntry(name: '..', path: parentPath, isParent: true),
      );
    }

    final children = <FolderBrowserEntry>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = p.basename(p.normalize(entity.path));
      if (!showHidden && name.startsWith('.')) continue;
      children.add(
        FolderBrowserEntry(
          name: name,
          path: p.normalize(entity.path),
          isParent: false,
        ),
      );
    }
    children.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    entries.addAll(children);

    return FolderBrowserSnapshot(
      path: p.normalize(directory.path),
      entries: List<FolderBrowserEntry>.unmodifiable(entries),
      parentPath: parentPath,
    );
  }

  static List<FolderBrowserShortcut> shortcuts(FolderPickerStrings strings) {
    final shortcuts = <FolderBrowserShortcut>[];
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Platform.environment['HOMEPATH'];
    if (home != null && Directory(home).existsSync()) {
      shortcuts.add(FolderBrowserShortcut(strings.home, p.normalize(home)));
    }

    if (Platform.isWindows) {
      for (var code = 65; code <= 90; code++) {
        final drive = '${String.fromCharCode(code)}:\\';
        if (Directory(drive).existsSync()) {
          shortcuts.add(FolderBrowserShortcut(drive, drive));
        }
      }
    } else {
      shortcuts.add(const FolderBrowserShortcut('/', '/'));
    }

    final seen = <String>{};
    return shortcuts.where((shortcut) {
      final key =
          Platform.isWindows ? shortcut.path.toLowerCase() : shortcut.path;
      return seen.add(key);
    }).toList(growable: false);
  }

  static bool _samePath(String left, String right) {
    final normalizedLeft = p.normalize(p.absolute(left));
    final normalizedRight = p.normalize(p.absolute(right));
    if (Platform.isWindows) {
      return normalizedLeft.toLowerCase() == normalizedRight.toLowerCase();
    }
    return normalizedLeft == normalizedRight;
  }
}

class FolderPicker extends StatefulWidget {
  const FolderPicker({
    super.key,
    required this.initialPath,
    required this.locale,
    required this.onSelected,
    required this.onCancel,
  });

  final String initialPath;
  final String locale;
  final ValueChanged<String> onSelected;
  final VoidCallback onCancel;

  @override
  State<FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<FolderPicker> {
  final _focusNode = FocusNode(debugLabel: 'Centra folder picker');
  FolderBrowserSnapshot? snapshot;
  late String currentPath;
  var selected = 0;
  var loading = false;
  var showHidden = false;
  String? error;

  FolderPickerStrings get strings =>
      FolderPickerStrings.forLocale(widget.locale);

  @override
  void initState() {
    super.initState();
    currentPath = FolderBrowser.nearestExisting(widget.initialPath);
    _reload(currentPath);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _reload(String path) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await FolderBrowser.read(path, showHidden: showHidden);
      if (!mounted) return;
      setState(() {
        snapshot = next;
        currentPath = next.path;
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
    final entries = snapshot?.entries ?? const <FolderBrowserEntry>[];
    if (entries.isEmpty) return;
    setState(() {
      selected = (selected + delta) % entries.length;
      if (selected < 0) selected += entries.length;
    });
  }

  Future<void> _openSelected() async {
    final entries = snapshot?.entries ?? const <FolderBrowserEntry>[];
    if (entries.isEmpty || selected >= entries.length) return;
    await _reload(entries[selected].path);
  }

  Future<void> _goParent() async {
    final parent = snapshot?.parentPath;
    if (parent != null) await _reload(parent);
  }

  void _selectCurrent() => widget.onSelected(currentPath);

  bool _handleKey(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape) {
      widget.onCancel();
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
    if (event.logicalKey == LogicalKey.enter) {
      _openSelected();
      return true;
    }
    if (event.logicalKey == LogicalKey.backspace ||
        event.logicalKey == LogicalKey.arrowLeft) {
      _goParent();
      return true;
    }
    if (event.logicalKey == LogicalKey.space) {
      _selectCurrent();
      return true;
    }
    if (event.logicalKey == LogicalKey.keyH) {
      setState(() => showHidden = !showHidden);
      _reload(currentPath);
      return true;
    }
    if (event.logicalKey == LogicalKey.keyR) {
      _reload(currentPath);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final entries = snapshot?.entries ?? const <FolderBrowserEntry>[];
    final shortcuts = FolderBrowser.shortcuts(strings);
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: SizedBox(
        width: 76,
        height: 24,
        child: Container(
          decoration: BoxDecoration(
            color: _pickerBackground,
            border: BoxBorder.all(
              color: _pickerAccent,
              style: BoxBorderStyle.rounded,
            ),
            title: BorderTitle(
              text: strings.title,
              style: const TextStyle(
                color: _pickerAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          padding: const EdgeInsets.all(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                strings.currentFolder,
                style: const TextStyle(color: _pickerMuted),
              ),
              Container(
                color: _pickerSurfaceStrong,
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(
                  currentPath,
                  maxLines: 1,
                  style: const TextStyle(color: _pickerText),
                ),
              ),
              const SizedBox(height: 1),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 17,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _pickerSurface,
                          border: BoxBorder.all(
                            color: const Color(0x27313D),
                            style: BoxBorderStyle.rounded,
                          ),
                          title: BorderTitle(
                            text: strings.roots,
                            style: const TextStyle(color: _pickerMuted),
                          ),
                        ),
                        padding: const EdgeInsets.all(1),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: shortcuts
                                .map(
                                  (shortcut) => GestureDetector(
                                    onTap: () => _reload(shortcut.path),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 1),
                                      child: Text(
                                        shortcut.label,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          color: _pickerText,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 1),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _pickerSurface,
                          border: BoxBorder.all(
                            color: const Color(0x27313D),
                            style: BoxBorderStyle.rounded,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: loading
                            ? Center(
                                child: Text(
                                  strings.loading,
                                  style: const TextStyle(color: _pickerMuted),
                                ),
                              )
                            : error != null
                                ? Center(
                                    child: Text(
                                      error!,
                                      style:
                                          const TextStyle(color: _pickerDanger),
                                    ),
                                  )
                                : entries.isEmpty
                                    ? Center(
                                        child: Text(
                                          strings.empty,
                                          style: const TextStyle(
                                              color: _pickerMuted),
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: entries
                                              .asMap()
                                              .entries
                                              .map(
                                                (entry) => GestureDetector(
                                                  onTap: () {
                                                    setState(
                                                      () =>
                                                          selected = entry.key,
                                                    );
                                                    _reload(entry.value.path);
                                                  },
                                                  child: Container(
                                                    color: selected == entry.key
                                                        ? _pickerSurfaceStrong
                                                        : null,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 1,
                                                    ),
                                                    child: Text(
                                                      '${entry.value.isParent ? '↰' : '▸'} ${entry.value.name}',
                                                      maxLines: 1,
                                                      style: TextStyle(
                                                        color: selected ==
                                                                entry.key
                                                            ? _pickerAccent
                                                            : _pickerText,
                                                        fontWeight: selected ==
                                                                entry.key
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(growable: false),
                                        ),
                                      ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () {
                      setState(() => showHidden = !showHidden);
                      _reload(currentPath);
                    },
                    child: Text(
                      showHidden ? strings.hideHidden : strings.showHidden,
                      style: const TextStyle(color: _pickerMuted),
                    ),
                  ),
                  const SizedBox(width: 2),
                  GestureDetector(
                    onTap: () => _reload(currentPath),
                    child: Text(
                      strings.refresh,
                      style: const TextStyle(color: _pickerMuted),
                    ),
                  ),
                  const Spacer(),
                  _FolderPickerButton(
                    label: strings.cancel,
                    onTap: widget.onCancel,
                    muted: true,
                  ),
                  const SizedBox(width: 1),
                  _FolderPickerButton(
                    label: strings.choose,
                    onTap: _selectCurrent,
                  ),
                ],
              ),
              Text(
                strings.help,
                maxLines: 1,
                style: const TextStyle(color: _pickerMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderPickerButton extends StatelessWidget {
  const _FolderPickerButton({
    required this.label,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          color: muted ? _pickerSurfaceStrong : _pickerAccent,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            style: TextStyle(
              color: muted ? _pickerText : _pickerBackground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}
