import 'package:cinder/cinder.dart';

import '../core/profile.dart';
import '../core/ssh_connection.dart';
import 'ssh_terminal_controller.dart';

const _sshAccent = Color(0x64D8CB);
const _sshBackground = Color(0x0D1117);
const _sshSurface = Color(0x151B23);
const _sshSurfaceStrong = Color(0x1D2632);
const _sshMuted = Color(0x7D8A99);
const _sshText = Color(0xE6EDF3);
const _sshDanger = Color(0xF47067);
const _sshSuccess = Color(0x56D364);
const _sshWarning = Color(0xE3B341);

class SshPickerStrings {
  const SshPickerStrings(this.locale);

  final String locale;

  String call(String key) =>
      _values[locale]?[key] ?? _values['en']![key] ?? key;

  static const _values = <String, Map<String, String>>{
    'en': <String, String>{
      'title': 'SSH connection',
      'address': 'Address',
      'host': 'Host or IP address',
      'port': 'Port',
      'user': 'Username',
      'authentication': 'Authentication',
      'password': 'Password',
      'privateKey': 'Private key',
      'passwordAndKey': 'Password + private key',
      'passwordHint': 'Password · never saved',
      'identityFile': 'Private key file',
      'passphrase': 'Key passphrase · never saved',
      'advanced': 'Connection options',
      'timeout': 'Timeout, seconds',
      'keepAlive': 'Keepalive, seconds (0 = off)',
      'connect': 'Connect and browse',
      'connecting': 'Connecting…',
      'connected': 'Connected',
      'fingerprint': 'Server fingerprint',
      'server': 'Server',
      'currentFolder': 'Remote folder',
      'choose': 'Use this folder',
      'back': 'Back',
      'cancel': 'Cancel',
      'refresh': 'Refresh',
      'terminal': 'Terminal',
      'files': 'Files',
      'openTerminal': 'Open terminal',
      'terminalHelp':
          'Ctrl+Shift+B files  Ctrl+Shift+R restart  PageUp/PageDown scroll',
      'empty': 'No subfolders',
      'loading': 'Reading remote filesystem…',
      'security':
          'The server fingerprint is pinned after the first successful connection.',
      'helpForm': 'Tab fields  Mouse supported  Esc cancel',
      'helpBrowser':
          '↑↓ move  Enter open  Backspace parent  Space choose  R refresh  Esc back',
    },
    'ru': <String, String>{
      'title': 'SSH-подключение',
      'address': 'Адрес',
      'host': 'Хост или IP-адрес',
      'port': 'Порт',
      'user': 'Пользователь',
      'authentication': 'Аутентификация',
      'password': 'Пароль',
      'privateKey': 'Приватный ключ',
      'passwordAndKey': 'Пароль + приватный ключ',
      'passwordHint': 'Пароль · никогда не сохраняется',
      'identityFile': 'Файл приватного ключа',
      'passphrase': 'Passphrase ключа · никогда не сохраняется',
      'advanced': 'Параметры подключения',
      'timeout': 'Таймаут, секунд',
      'keepAlive': 'Keepalive, секунд (0 = выкл.)',
      'connect': 'Подключиться и открыть',
      'connecting': 'Подключение…',
      'connected': 'Подключено',
      'fingerprint': 'Отпечаток сервера',
      'server': 'SSH-сервер',
      'currentFolder': 'Удалённая папка',
      'choose': 'Выбрать эту папку',
      'back': 'Назад',
      'cancel': 'Отмена',
      'refresh': 'Обновить',
      'terminal': 'Терминал',
      'files': 'Файлы',
      'openTerminal': 'Открыть терминал',
      'terminalHelp':
          'Ctrl+Shift+B файлы  Ctrl+Shift+R перезапуск  PageUp/PageDown прокрутка',
      'empty': 'Вложенных папок нет',
      'loading': 'Чтение файловой системы сервера…',
      'security':
          'После первого успешного подключения отпечаток сервера закрепляется в профиле.',
      'helpForm': 'Tab поля  Мышь поддерживается  Esc отмена',
      'helpBrowser':
          '↑↓ выбор  Enter открыть  Backspace вверх  Space выбрать  R обновить  Esc назад',
    },
    'uz': <String, String>{
      'title': 'SSH ulanish',
      'address': 'Manzil',
      'host': 'Host yoki IP manzil',
      'port': 'Port',
      'user': 'Foydalanuvchi',
      'authentication': 'Autentifikatsiya',
      'password': 'Parol',
      'privateKey': 'Shaxsiy kalit',
      'passwordAndKey': 'Parol + shaxsiy kalit',
      'passwordHint': 'Parol · saqlanmaydi',
      'identityFile': 'Shaxsiy kalit fayli',
      'passphrase': 'Kalit paroli · saqlanmaydi',
      'advanced': 'Ulanish parametrlari',
      'timeout': 'Kutish vaqti, soniya',
      'keepAlive': 'Keepalive, soniya (0 = o‘chiq)',
      'connect': 'Ulanish va ko‘rish',
      'connecting': 'Ulanmoqda…',
      'connected': 'Ulandi',
      'fingerprint': 'Server izi',
      'server': 'SSH server',
      'currentFolder': 'Masofaviy papka',
      'choose': 'Shu papkani tanlash',
      'back': 'Orqaga',
      'cancel': 'Bekor qilish',
      'refresh': 'Yangilash',
      'empty': 'Ichki papkalar yo‘q',
      'loading': 'Server fayl tizimi o‘qilmoqda…',
      'security':
          'Birinchi muvaffaqiyatli ulanishdan so‘ng server izi profilga biriktiriladi.',
      'helpForm': 'Tab maydonlar  Sichqoncha ishlaydi  Esc bekor',
      'helpBrowser':
          '↑↓ tanlash  Enter ochish  Backspace yuqori  Space tanlash  R yangilash  Esc orqaga',
    },
    'uz-Cyrl': <String, String>{
      'title': 'SSH уланиш',
      'address': 'Манзил',
      'host': 'Хост ёки IP манзил',
      'port': 'Порт',
      'user': 'Фойдаланувчи',
      'authentication': 'Аутентификация',
      'password': 'Парол',
      'privateKey': 'Шахсий калит',
      'passwordAndKey': 'Парол + шахсий калит',
      'passwordHint': 'Парол · сақланмайди',
      'identityFile': 'Шахсий калит файли',
      'passphrase': 'Калит пароли · сақланмайди',
      'advanced': 'Уланиш параметрлари',
      'timeout': 'Кутиш вақти, сония',
      'keepAlive': 'Keepalive, сония (0 = ўчиқ)',
      'connect': 'Уланиш ва кўриш',
      'connecting': 'Уланмоқда…',
      'connected': 'Уланди',
      'fingerprint': 'Сервер изи',
      'server': 'SSH сервер',
      'currentFolder': 'Масофавий папка',
      'choose': 'Шу папкани танлаш',
      'back': 'Орқага',
      'cancel': 'Бекор қилиш',
      'refresh': 'Янгилаш',
      'empty': 'Ички папкалар йўқ',
      'loading': 'Сервер файл тизими ўқилмоқда…',
      'security':
          'Биринчи муваффақиятли уланишдан сўнг сервер изи профилга бириктирилади.',
      'helpForm': 'Tab майдонлар  Сичқонча ишлайди  Esc бекор',
      'helpBrowser':
          '↑↓ танлаш  Enter очиш  Backspace юқори  Space танлаш  R янгилаш  Esc орқага',
    },
    'tr': <String, String>{
      'title': 'SSH bağlantısı',
      'address': 'Adres',
      'host': 'Sunucu veya IP adresi',
      'port': 'Port',
      'user': 'Kullanıcı',
      'authentication': 'Kimlik doğrulama',
      'password': 'Parola',
      'privateKey': 'Özel anahtar',
      'passwordAndKey': 'Parola + özel anahtar',
      'passwordHint': 'Parola · kaydedilmez',
      'identityFile': 'Özel anahtar dosyası',
      'passphrase': 'Anahtar parolası · kaydedilmez',
      'advanced': 'Bağlantı seçenekleri',
      'timeout': 'Zaman aşımı, saniye',
      'keepAlive': 'Keepalive, saniye (0 = kapalı)',
      'connect': 'Bağlan ve gözat',
      'connecting': 'Bağlanıyor…',
      'connected': 'Bağlandı',
      'fingerprint': 'Sunucu parmak izi',
      'server': 'SSH sunucusu',
      'currentFolder': 'Uzak klasör',
      'choose': 'Bu klasörü kullan',
      'back': 'Geri',
      'cancel': 'İptal',
      'refresh': 'Yenile',
      'empty': 'Alt klasör yok',
      'loading': 'Uzak dosya sistemi okunuyor…',
      'security':
          'İlk başarılı bağlantıdan sonra sunucu parmak izi profile sabitlenir.',
      'helpForm': 'Tab alanlar  Fare desteklenir  Esc iptal',
      'helpBrowser':
          '↑↓ seç  Enter aç  Backspace üst  Space kullan  R yenile  Esc geri',
    },
    'kk': <String, String>{},
    'ky': <String, String>{},
    'tg': <String, String>{},
    'az': <String, String>{},
    'de': <String, String>{
      'title': 'SSH-Verbindung',
      'address': 'Adresse',
      'host': 'Host oder IP-Adresse',
      'port': 'Port',
      'user': 'Benutzer',
      'authentication': 'Authentifizierung',
      'password': 'Passwort',
      'privateKey': 'Privater Schlüssel',
      'passwordAndKey': 'Passwort + privater Schlüssel',
      'passwordHint': 'Passwort · wird nie gespeichert',
      'identityFile': 'Datei des privaten Schlüssels',
      'passphrase': 'Schlüssel-Passphrase · wird nie gespeichert',
      'advanced': 'Verbindungsoptionen',
      'timeout': 'Zeitlimit, Sekunden',
      'keepAlive': 'Keepalive, Sekunden (0 = aus)',
      'connect': 'Verbinden und durchsuchen',
      'connecting': 'Verbindung wird hergestellt…',
      'connected': 'Verbunden',
      'fingerprint': 'Server-Fingerabdruck',
      'server': 'SSH-Server',
      'currentFolder': 'Entfernter Ordner',
      'choose': 'Diesen Ordner verwenden',
      'back': 'Zurück',
      'cancel': 'Abbrechen',
      'refresh': 'Aktualisieren',
      'empty': 'Keine Unterordner',
      'loading': 'Entferntes Dateisystem wird gelesen…',
      'security':
          'Nach der ersten erfolgreichen Verbindung wird der Fingerabdruck im Profil fixiert.',
      'helpForm': 'Tab Felder  Maus unterstützt  Esc abbrechen',
      'helpBrowser':
          '↑↓ wählen  Enter öffnen  Backspace hoch  Space verwenden  R neu  Esc zurück',
    },
  };
}

class SshSourcePicker extends StatefulWidget {
  const SshSourcePicker({
    super.key,
    required this.locale,
    required this.onSelected,
    required this.onCancel,
    this.initialHost = '',
    this.initialPort = 22,
    this.initialUser = '',
    this.initialPath = '/',
    this.initialAuthMethod = SshAuthMethod.password,
    this.initialIdentityFile,
    this.initialFingerprint,
    this.initialConnectTimeoutSeconds = 15,
    this.initialKeepAliveSeconds = 10,
    this.initialSecrets = const SshConnectionSecrets(),
  });

  final String locale;
  final String initialHost;
  final int initialPort;
  final String initialUser;
  final String initialPath;
  final SshAuthMethod initialAuthMethod;
  final String? initialIdentityFile;
  final String? initialFingerprint;
  final int initialConnectTimeoutSeconds;
  final int initialKeepAliveSeconds;
  final SshConnectionSecrets initialSecrets;
  final ValueChanged<SshSourceSelection> onSelected;
  final VoidCallback onCancel;

  @override
  State<SshSourcePicker> createState() => _SshSourcePickerState();
}

class _SshSourcePickerState extends State<SshSourcePicker> {
  final service = const SshConnectionService();
  final focus = FocusNode(debugLabel: 'Centra SSH connection');
  final hostFocus = FocusNode(debugLabel: 'SSH host');
  final portFocus = FocusNode(debugLabel: 'SSH port');
  final userFocus = FocusNode(debugLabel: 'SSH user');
  final passwordFocus = FocusNode(debugLabel: 'SSH password');
  final identityFocus = FocusNode(debugLabel: 'SSH identity');
  final passphraseFocus = FocusNode(debugLabel: 'SSH passphrase');
  final timeoutFocus = FocusNode(debugLabel: 'SSH timeout');
  final keepAliveFocus = FocusNode(debugLabel: 'SSH keepalive');
  final directoryScroll = ScrollController();

  late final TextEditingController host;
  late final TextEditingController port;
  late final TextEditingController user;
  late final TextEditingController password;
  late final TextEditingController identityFile;
  late final TextEditingController passphrase;
  late final TextEditingController timeout;
  late final TextEditingController keepAlive;
  late SshAuthMethod authMethod;

  SshConnection? connection;
  SshDirectoryListing? listing;
  var selected = 0;
  var connecting = false;
  var terminalMode = false;
  SshTerminalController? terminalController;
  String? error;

  SshPickerStrings get strings => SshPickerStrings(widget.locale);
  bool get browsing => connection != null;

  List<FocusNode> get fieldFocusNodes => <FocusNode>[
        hostFocus,
        portFocus,
        userFocus,
        passwordFocus,
        identityFocus,
        passphraseFocus,
        timeoutFocus,
        keepAliveFocus,
      ];

  @override
  void initState() {
    super.initState();
    host = TextEditingController(text: widget.initialHost);
    port = TextEditingController(text: widget.initialPort.toString());
    user = TextEditingController(text: widget.initialUser);
    password = TextEditingController(
      text: widget.initialSecrets.password ?? '',
    );
    identityFile = TextEditingController(
      text: widget.initialIdentityFile ?? '',
    );
    passphrase = TextEditingController(
      text: widget.initialSecrets.keyPassphrase ?? '',
    );
    timeout = TextEditingController(
      text: widget.initialConnectTimeoutSeconds.toString(),
    );
    keepAlive = TextEditingController(
      text: widget.initialKeepAliveSeconds.toString(),
    );
    authMethod = widget.initialAuthMethod;
  }

  @override
  void dispose() {
    terminalController?.dispose();
    connection?.close();
    for (final controller in <TextEditingController>[
      host,
      port,
      user,
      password,
      identityFile,
      passphrase,
      timeout,
      keepAlive,
    ]) {
      controller.dispose();
    }
    for (final node in <FocusNode>[focus, ...fieldFocusNodes]) {
      node.dispose();
    }
    directoryScroll.dispose();
    super.dispose();
  }

  SourceConfig _config() => SourceConfig(
        type: SourceType.ssh,
        root: widget.initialPath,
        host: host.text.trim(),
        user: user.text.trim(),
        port: int.tryParse(port.text.trim()) ?? 0,
        identityFile:
            authMethod.usesPrivateKey ? identityFile.text.trim() : null,
        sshAuthMethod: authMethod,
        sshHostKeyPolicy: SshHostKeyPolicy.trustOnFirstUse,
        hostKeyFingerprint: widget.initialFingerprint,
        connectTimeoutSeconds: int.tryParse(timeout.text.trim()) ?? 0,
        keepAliveSeconds: int.tryParse(keepAlive.text.trim()) ?? -1,
      );

  SshConnectionSecrets _secrets() => SshConnectionSecrets(
        password: authMethod.usesPassword ? password.text : null,
        keyPassphrase: authMethod.usesPrivateKey ? passphrase.text : null,
      );

  Future<void> _connect() async {
    if (connecting) return;
    setState(() {
      connecting = true;
      error = null;
    });
    try {
      final next = await service.connect(
        _config(),
        secrets: _secrets(),
        acceptUnknownHost: widget.initialFingerprint == null ||
            widget.initialFingerprint!.isEmpty,
      );
      final first = await next.listDirectories(widget.initialPath);
      if (!mounted) {
        await next.close();
        return;
      }
      setState(() {
        connection = next;
        listing = first;
        selected = 0;
        connecting = false;
      });
      focus.requestFocus();
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        connecting = false;
      });
    }
  }

  Future<void> _loadDirectory(String path) async {
    final active = connection;
    if (active == null) return;
    setState(() {
      connecting = true;
      error = null;
    });
    try {
      final next = await active.listDirectories(path);
      if (!mounted) return;
      setState(() {
        listing = next;
        selected = 0;
        connecting = false;
      });
      _ensureSelectedVisible();
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        connecting = false;
      });
    }
  }

  void _move(int delta) {
    final entries = listing?.entries ?? const <SshDirectoryEntry>[];
    if (entries.isEmpty) return;
    setState(() {
      selected = (selected + delta) % entries.length;
      if (selected < 0) selected += entries.length;
    });
    _ensureSelectedVisible();
  }

  void _jumpToIndex(int index) {
    final entries = listing?.entries ?? const <SshDirectoryEntry>[];
    if (entries.isEmpty) return;
    setState(() => selected = index.clamp(0, entries.length - 1));
    _ensureSelectedVisible();
  }

  void _ensureSelectedVisible() {
    void ensure() => directoryScroll.ensureIndexVisible(index: selected);
    try {
      TerminalBinding.instance.addPostFrameCallback((_) => ensure());
    } on Object {
      ensure();
    }
  }

  Future<void> _openTerminal() async {
    final active = connection;
    if (active == null || terminalMode) return;
    setState(() {
      terminalController = SshTerminalController(connection: active);
      terminalMode = true;
      error = null;
    });
  }

  Future<void> _closeTerminal() async {
    final controller = terminalController;
    terminalController = null;
    await controller?.dispose();
    if (!mounted) return;
    setState(() => terminalMode = false);
    focus.requestFocus();
    _ensureSelectedVisible();
  }

  bool _handleTerminalKey(KeyboardEvent event) {
    if (event.matches(LogicalKey.keyB, ctrl: true, shift: true)) {
      _closeTerminal();
      return true;
    }
    if (event.matches(LogicalKey.keyR, ctrl: true, shift: true)) {
      terminalController?.restart();
      return true;
    }
    return false;
  }

  Future<void> _activate() async {
    final entries = listing?.entries ?? const <SshDirectoryEntry>[];
    if (entries.isEmpty || selected >= entries.length) return;
    await _loadDirectory(entries[selected].path);
  }

  Future<void> _back() async {
    if (terminalMode) {
      await _closeTerminal();
      return;
    }
    if (!browsing) {
      await _cancel();
      return;
    }
    final parent = listing?.parentPath;
    if (parent != null) {
      await _loadDirectory(parent);
      return;
    }
    final active = connection;
    connection = null;
    listing = null;
    await active?.close();
    if (!mounted) return;
    setState(() {
      selected = 0;
      error = null;
    });
  }

  Future<void> _choose() async {
    await _closeTerminal();
    final active = connection;
    final current = listing;
    if (active == null || current == null) return;
    final selection = SshSourceSelection(
      host: host.text.trim(),
      port: int.parse(port.text.trim()),
      user: user.text.trim(),
      path: current.path,
      authMethod: authMethod,
      identityFile: authMethod.usesPrivateKey ? identityFile.text.trim() : null,
      hostKeyType: active.hostKeyType,
      hostKeyFingerprint: active.hostKeyFingerprint,
      connectTimeoutSeconds: int.parse(timeout.text.trim()),
      keepAliveSeconds: int.parse(keepAlive.text.trim()),
      serverVersion: active.serverVersion,
      secrets: _secrets(),
    );
    connection = null;
    await active.close();
    widget.onSelected(selection);
  }

  Future<void> _cancel() async {
    await _closeTerminal();
    final active = connection;
    connection = null;
    await active?.close();
    widget.onCancel();
  }

  bool _handleKey(KeyboardEvent event) {
    if (fieldFocusNodes.any((node) => node.hasPrimaryFocus)) {
      if (event.logicalKey == LogicalKey.escape) {
        FocusManager.instance.primaryFocus?.unfocus();
        focus.requestFocus();
        return true;
      }
      return false;
    }
    if (event.logicalKey == LogicalKey.escape) {
      _back();
      return true;
    }
    if (!browsing) return false;
    if (event.logicalKey == LogicalKey.arrowUp) {
      _move(-1);
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowDown) {
      _move(1);
      return true;
    }
    if (event.logicalKey == LogicalKey.pageUp) {
      final page = directoryScroll.viewportDimension > 1
          ? directoryScroll.viewportDimension.floor() - 1
          : 10;
      _move(-page);
      return true;
    }
    if (event.logicalKey == LogicalKey.pageDown) {
      final page = directoryScroll.viewportDimension > 1
          ? directoryScroll.viewportDimension.floor() - 1
          : 10;
      _move(page);
      return true;
    }
    if (event.logicalKey == LogicalKey.home) {
      _jumpToIndex(0);
      return true;
    }
    if (event.logicalKey == LogicalKey.end) {
      _jumpToIndex((listing?.entries.length ?? 1) - 1);
      return true;
    }
    if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.arrowRight) {
      _activate();
      return true;
    }
    if (event.logicalKey == LogicalKey.backspace ||
        event.logicalKey == LogicalKey.arrowLeft) {
      _back();
      return true;
    }
    if (event.logicalKey == LogicalKey.space) {
      _choose();
      return true;
    }
    if (event.logicalKey == LogicalKey.keyR) {
      _loadDirectory(listing?.path ?? '/');
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focus,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: SizedBox(
        width: 94,
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: _sshBackground,
            border: BoxBorder.all(
              color: _sshAccent,
              style: BoxBorderStyle.rounded,
            ),
            title: BorderTitle(
              text: strings('title'),
              style: const TextStyle(
                color: _sshAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          padding: const EdgeInsets.all(1),
          child: terminalMode
              ? _terminal()
              : browsing
                  ? _browser()
                  : _form(),
        ),
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(strings('address'), style: const TextStyle(color: _sshAccent)),
        Row(
          children: <Widget>[
            Expanded(
              child: _field(
                strings('host'),
                host,
                hostFocus,
                'server.example.com',
              ),
            ),
            const SizedBox(width: 1),
            SizedBox(
              width: 14,
              child: _field(strings('port'), port, portFocus, '22'),
            ),
          ],
        ),
        _field(strings('user'), user, userFocus, 'deploy'),
        Text(
          strings('authentication'),
          style: const TextStyle(color: _sshAccent),
        ),
        Row(
          children: SshAuthMethod.values
              .map(
                (method) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 1),
                    child: _choice(
                      _authLabel(method),
                      authMethod == method,
                      () => setState(() => authMethod = method),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        if (authMethod.usesPassword)
          _field(
            strings('passwordHint'),
            password,
            passwordFocus,
            '••••••••',
            obscureText: true,
          ),
        if (authMethod.usesPrivateKey)
          Row(
            children: <Widget>[
              Expanded(
                child: _field(
                  strings('identityFile'),
                  identityFile,
                  identityFocus,
                  '~/.ssh/id_ed25519',
                ),
              ),
              const SizedBox(width: 1),
              Expanded(
                child: _field(
                  strings('passphrase'),
                  passphrase,
                  passphraseFocus,
                  'optional',
                  obscureText: true,
                ),
              ),
            ],
          ),
        Text(strings('advanced'), style: const TextStyle(color: _sshAccent)),
        Row(
          children: <Widget>[
            Expanded(
              child: _field(strings('timeout'), timeout, timeoutFocus, '15'),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: _field(
                strings('keepAlive'),
                keepAlive,
                keepAliveFocus,
                '10',
              ),
            ),
          ],
        ),
        Text(strings('security'), style: const TextStyle(color: _sshMuted)),
        if (widget.initialFingerprint != null &&
            widget.initialFingerprint!.isNotEmpty)
          Text(
            '${strings('fingerprint')}: ${widget.initialFingerprint}',
            maxLines: 1,
            style: const TextStyle(color: _sshSuccess),
          ),
        if (error != null)
          Text(error!, maxLines: 2, style: const TextStyle(color: _sshDanger)),
        const SizedBox(height: 1),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            _button(strings('cancel'), _cancel, muted: true),
            const SizedBox(width: 1),
            _button(
              connecting ? strings('connecting') : strings('connect'),
              _connect,
              disabled: connecting,
            ),
          ],
        ),
        Text(strings('helpForm'), style: const TextStyle(color: _sshMuted)),
      ],
    );
  }

  Widget _browser() {
    final active = connection!;
    final current = listing;
    final entries = current?.entries ?? const <SshDirectoryEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text('● ', style: TextStyle(color: _sshSuccess)),
            Expanded(
              child: Text(
                '${strings('connected')}: ${user.text}@${host.text}:${port.text}',
                maxLines: 1,
                style: const TextStyle(
                  color: _sshText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Text(
          '${strings('server')}: ${active.serverVersion ?? 'SSH'}',
          maxLines: 1,
          style: const TextStyle(color: _sshMuted),
        ),
        Text(
          '${strings('fingerprint')}: ${active.hostKeyType} ${active.hostKeyFingerprint}',
          maxLines: 1,
          style: const TextStyle(color: _sshWarning),
        ),
        const SizedBox(height: 1),
        Text(
          strings('currentFolder'),
          style: const TextStyle(color: _sshMuted),
        ),
        Container(
          color: _sshSurfaceStrong,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            current?.path ?? '/',
            maxLines: 1,
            style: const TextStyle(color: _sshAccent),
          ),
        ),
        const SizedBox(height: 1),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _sshSurface,
              border: BoxBorder.all(
                color: const Color(0x27313D),
                style: BoxBorderStyle.rounded,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: connecting
                ? Center(
                    child: Text(
                      strings('loading'),
                      style: const TextStyle(color: _sshMuted),
                    ),
                  )
                : error != null
                    ? Center(
                        child: Text(
                          error!,
                          style: const TextStyle(color: _sshDanger),
                        ),
                      )
                    : entries.isEmpty
                        ? Center(
                            child: Text(
                              strings('empty'),
                              style: const TextStyle(color: _sshMuted),
                            ),
                          )
                        : ListView.builder(
                            controller: directoryScroll,
                            itemCount: entries.length,
                            itemExtent: 1,
                            lazy: false,
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return GestureDetector(
                                onTap: () {
                                  setState(() => selected = index);
                                  _ensureSelectedVisible();
                                  _loadDirectory(entry.path);
                                },
                                child: Container(
                                  color: selected == index
                                      ? _sshSurfaceStrong
                                      : null,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  child: Text(
                                    '${entry.isParent ? '↰' : '▸'} ${entry.name}',
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: selected == index
                                          ? _sshAccent
                                          : _sshText,
                                      fontWeight: selected == index
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ),
        const SizedBox(height: 1),
        Row(
          children: <Widget>[
            _button(
              strings('refresh'),
              () => _loadDirectory(current?.path ?? '/'),
              muted: true,
            ),
            const SizedBox(width: 1),
            _button(strings('openTerminal'), _openTerminal, muted: true),
            const Spacer(),
            _button(strings('back'), _back, muted: true),
            const SizedBox(width: 1),
            _button(strings('choose'), _choose),
          ],
        ),
        Text(strings('helpBrowser'), style: const TextStyle(color: _sshMuted)),
      ],
    );
  }

  Widget _terminal() {
    final controller = terminalController!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text('● ', style: TextStyle(color: _sshSuccess)),
            Expanded(
              child: Text(
                '${user.text}@${host.text}:${port.text}',
                maxLines: 1,
                style: const TextStyle(
                  color: _sshText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              strings('terminal'),
              style: const TextStyle(color: _sshAccent),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _sshSurface,
              border: BoxBorder.all(
                color: const Color(0x27313D),
                style: BoxBorderStyle.rounded,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: TerminalXterm(
              controller: controller,
              focused: true,
              autoStart: true,
              maxLines: 20000,
              onKeyEvent: _handleTerminalKey,
            ),
          ),
        ),
        const SizedBox(height: 1),
        Row(
          children: <Widget>[
            _button(strings('files'), _closeTerminal, muted: true),
            const Spacer(),
            Text(
              strings('terminalHelp'),
              style: const TextStyle(color: _sshMuted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    FocusNode node,
    String placeholder, {
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(label, maxLines: 1, style: const TextStyle(color: _sshMuted)),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: node.requestFocus,
            child: TextField(
              controller: controller,
              focusNode: node,
              placeholder: placeholder,
              obscureText: obscureText,
              style: const TextStyle(color: _sshText),
              placeholderStyle: const TextStyle(
                color: _sshMuted,
                fontStyle: FontStyle.italic,
              ),
              decoration: InputDecoration(
                fillColor: _sshSurfaceStrong,
                border: BoxBorder.all(
                  color: const Color(0x394453),
                  style: BoxBorderStyle.rounded,
                ),
                focusedBorder: BoxBorder.all(
                  color: _sshAccent,
                  style: BoxBorderStyle.rounded,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: selected ? _sshSurfaceStrong : _sshSurface,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Text(
          '${selected ? '●' : '○'} $label',
          maxLines: 1,
          style: TextStyle(
            color: selected ? _sshAccent : _sshMuted,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _authLabel(SshAuthMethod method) => switch (method) {
        SshAuthMethod.password => strings('password'),
        SshAuthMethod.privateKey => strings('privateKey'),
        SshAuthMethod.passwordAndKey => strings('passwordAndKey'),
      };

  Widget _button(
    String label,
    Future<void> Function() onTap, {
    bool muted = false,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        color: disabled
            ? _sshSurface
            : muted
                ? _sshSurfaceStrong
                : _sshAccent,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          label,
          style: TextStyle(
            color: disabled
                ? _sshMuted
                : muted
                    ? _sshText
                    : _sshBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
