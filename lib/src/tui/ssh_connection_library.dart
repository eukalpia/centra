import 'package:cinder/cinder.dart';

import '../core/profile.dart';
import '../core/ssh_connection.dart';
import '../core/ssh_library.dart';
import '../core/storage.dart';
import 'ssh_source_picker.dart';

const _libraryAccent = Color(0x64D8CB);
const _libraryBackground = Color(0x0D1117);
const _librarySurface = Color(0x151B23);
const _librarySurfaceStrong = Color(0x1D2632);
const _libraryMuted = Color(0x7D8A99);
const _libraryText = Color(0xE6EDF3);
const _libraryDanger = Color(0xF47067);

class SshConnectionLibrary extends StatefulWidget {
  const SshConnectionLibrary({
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
    this.store,
  });

  final String locale;
  final ValueChanged<SshSourceSelection> onSelected;
  final VoidCallback onCancel;
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
  final SshConnectionStore? store;

  @override
  State<SshConnectionLibrary> createState() => _SshConnectionLibraryState();
}

class _SshConnectionLibraryState extends State<SshConnectionLibrary> {
  late final SshConnectionStore store;
  final name = TextEditingController();
  final nameFocus = FocusNode(debugLabel: 'SSH connection name');
  List<SshSavedConnection> connections = const <SshSavedConnection>[];
  SshSavedConnection? selected;
  var loading = true;
  var pickerOpen = false;
  var confirmDelete = false;
  String? error;

  bool get isRussian => widget.locale == 'ru';
  String text(String en, String ru) => isRussian ? ru : en;

  @override
  void initState() {
    super.initState();
    store = widget.store ?? SshConnectionStore(CentraPaths());
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    nameFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await store.list();
      if (!mounted) return;
      setState(() {
        connections = values;
        selected = values.isEmpty ? null : values.first;
        name.text = selected?.name ?? '';
        loading = false;
      });
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = exception.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (pickerOpen) return _picker();
    return SizedBox(
      width: 104,
      height: 35,
      child: Container(
        decoration: BoxDecoration(
          color: _libraryBackground,
          border: BoxBorder.all(
            color: _libraryAccent,
            style: BoxBorderStyle.rounded,
          ),
          title: BorderTitle(
            text: text('SSH connections', 'SSH-подключения'),
            style: const TextStyle(
              color: _libraryAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        padding: const EdgeInsets.all(1),
        child: loading
            ? Center(child: Text(text('Loading…', 'Загрузка…')))
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(flex: 2, child: _list()),
                  const SizedBox(width: 1),
                  Expanded(flex: 3, child: _details()),
                ],
              ),
      ),
    );
  }

  Widget _list() => Container(
        color: _librarySurface,
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              text('Saved servers', 'Сохранённые серверы'),
              style: const TextStyle(
                color: _libraryMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 1),
            Expanded(
              child: connections.isEmpty
                  ? Text(
                      text(
                        'No saved connections yet.',
                        'Сохранённых подключений пока нет.',
                      ),
                      style: const TextStyle(color: _libraryMuted),
                    )
                  : ListView.builder(
                      itemCount: connections.length,
                      itemBuilder: (context, index) {
                        final connection = connections[index];
                        final active = selected?.id == connection.id;
                        return GestureDetector(
                          onTap: () => setState(() {
                            selected = connection;
                            name.text = connection.name;
                            confirmDelete = false;
                          }),
                          child: Container(
                            color: active ? _librarySurfaceStrong : null,
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  '${connection.favorite ? '★ ' : ''}${connection.name}',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color:
                                        active ? _libraryAccent : _libraryText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  connection.endpoint,
                                  maxLines: 1,
                                  style: const TextStyle(color: _libraryMuted),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 1),
            _button(text('+ Add connection', '+ Добавить подключение'), _new),
          ],
        ),
      );

  Widget _details() {
    final connection = selected;
    return Container(
      color: _librarySurface,
      padding: const EdgeInsets.all(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            text('Connection name', 'Имя подключения'),
            style: const TextStyle(color: _libraryMuted),
          ),
          TextField(
            controller: name,
            focusNode: nameFocus,
            placeholder: text('Production server', 'Production сервер'),
          ),
          const SizedBox(height: 1),
          if (connection == null)
            Text(
              text(
                'Create a named server entry, then connect and choose a remote directory.',
                'Создайте именованное подключение, затем войдите и выберите удалённую папку.',
              ),
              style: const TextStyle(color: _libraryMuted),
            )
          else ...<Widget>[
            _detail(text('Endpoint', 'Адрес'), connection.endpoint),
            _detail(
              text('Authentication', 'Авторизация'),
              connection.authMethod.wireName,
            ),
            _detail(
                text('Last directory', 'Последняя папка'), connection.lastPath),
            _detail(
              text('Host fingerprint', 'Fingerprint сервера'),
              connection.hostKeyFingerprint ??
                  text('Not pinned', 'Не закреплён'),
            ),
            _detail(
              text('Last connected', 'Последнее подключение'),
              connection.lastConnectedAt?.toLocal().toIso8601String() ?? '—',
            ),
            _detail(
              text('Secrets', 'Секреты'),
              text('Requested per session · never saved',
                  'Запрашиваются на сессию · не сохраняются'),
            ),
          ],
          const Spacer(),
          if (error != null)
            Text(error!, style: const TextStyle(color: _libraryDanger)),
          Row(
            children: <Widget>[
              _button(text('Back', 'Назад'), widget.onCancel, muted: true),
              const Spacer(),
              if (connection != null) ...<Widget>[
                _button(
                  text('Duplicate', 'Дублировать'),
                  _duplicate,
                  muted: true,
                ),
                const SizedBox(width: 1),
                _button(
                  confirmDelete
                      ? text('Confirm delete', 'Подтвердить удаление')
                      : text('Delete', 'Удалить'),
                  _delete,
                  danger: confirmDelete,
                  muted: !confirmDelete,
                ),
                const SizedBox(width: 1),
              ],
              _button(
                connection == null
                    ? text('Configure', 'Настроить')
                    : text('Connect', 'Подключиться'),
                _openPicker,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 22,
              child: Text(label, style: const TextStyle(color: _libraryMuted)),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                style: const TextStyle(color: _libraryText),
              ),
            ),
          ],
        ),
      );

  Widget _picker() {
    final connection = selected;
    return SshSourcePicker(
      locale: widget.locale,
      initialHost: connection?.host ?? widget.initialHost,
      initialPort: connection?.port ?? widget.initialPort,
      initialUser: connection?.user ?? widget.initialUser,
      initialPath: connection?.lastPath ?? widget.initialPath,
      initialAuthMethod: connection?.authMethod ?? widget.initialAuthMethod,
      initialIdentityFile:
          connection?.identityFile ?? widget.initialIdentityFile,
      initialFingerprint:
          connection?.hostKeyFingerprint ?? widget.initialFingerprint,
      initialConnectTimeoutSeconds: connection?.connectTimeoutSeconds ??
          widget.initialConnectTimeoutSeconds,
      initialKeepAliveSeconds:
          connection?.keepAliveSeconds ?? widget.initialKeepAliveSeconds,
      initialSecrets: widget.initialSecrets,
      onSelected: _saveSelection,
      onCancel: () => setState(() => pickerOpen = false),
    );
  }

  void _new() {
    setState(() {
      selected = null;
      name.clear();
      error = null;
      confirmDelete = false;
    });
    nameFocus.requestFocus();
  }

  void _openPicker() {
    if (name.text.trim().isEmpty) {
      setState(() => error = text(
            'Enter a connection name first.',
            'Сначала укажите имя подключения.',
          ));
      nameFocus.requestFocus();
      return;
    }
    setState(() {
      pickerOpen = true;
      error = null;
    });
  }

  Future<void> _saveSelection(SshSourceSelection selection) async {
    try {
      final now = DateTime.now().toUtc();
      var connection = selected;
      if (connection == null) {
        connection = await store.create(
          name: name.text.trim(),
          host: selection.host,
          port: selection.port,
          user: selection.user,
          authMethod: selection.authMethod,
          identityFile: selection.identityFile,
          connectTimeoutSeconds: selection.connectTimeoutSeconds,
          keepAliveSeconds: selection.keepAliveSeconds,
          lastPath: selection.path,
        );
      }
      connection = connection.copyWith(
        name: name.text.trim(),
        host: selection.host,
        port: selection.port,
        user: selection.user,
        authMethod: selection.authMethod,
        identityFile: selection.identityFile,
        hostKeyType: selection.hostKeyType,
        hostKeyFingerprint: selection.hostKeyFingerprint,
        connectTimeoutSeconds: selection.connectTimeoutSeconds,
        keepAliveSeconds: selection.keepAliveSeconds,
        lastPath: selection.path,
        lastConnectedAt: now,
        updatedAt: now,
      );
      await store.save(connection);
      widget.onSelected(SshSourceSelection(
        host: selection.host,
        port: selection.port,
        user: selection.user,
        path: selection.path,
        authMethod: selection.authMethod,
        identityFile: selection.identityFile,
        hostKeyType: selection.hostKeyType,
        hostKeyFingerprint: selection.hostKeyFingerprint,
        connectTimeoutSeconds: selection.connectTimeoutSeconds,
        keepAliveSeconds: selection.keepAliveSeconds,
        serverVersion: selection.serverVersion,
        secrets: selection.secrets,
        connectionId: connection.id,
        connectionName: connection.name,
      ));
    } on Object catch (exception) {
      if (!mounted) return;
      setState(() {
        pickerOpen = false;
        error = exception.toString();
      });
    }
  }

  Future<void> _duplicate() async {
    final connection = selected;
    if (connection == null) return;
    try {
      final duplicate = await store.duplicate(
        connection.id,
        name: '${connection.name} copy',
      );
      await _load();
      if (!mounted) return;
      setState(() {
        selected = duplicate;
        name.text = duplicate.name;
      });
    } on Object catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  Future<void> _delete() async {
    final connection = selected;
    if (connection == null) return;
    if (!confirmDelete) {
      setState(() => confirmDelete = true);
      return;
    }
    await store.delete(connection.id);
    confirmDelete = false;
    await _load();
  }

  Widget _button(
    String label,
    VoidCallback? onTap, {
    bool muted = false,
    bool danger = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          color: onTap == null
              ? const Color(0x27313D)
              : danger
                  ? _libraryDanger
                  : muted
                      ? _librarySurfaceStrong
                      : _libraryAccent,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null
                  ? _libraryMuted
                  : muted
                      ? _libraryText
                      : _libraryBackground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}
