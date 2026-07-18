import '../util/json.dart';
import 'profile.dart';
import 'storage.dart';

class SshSavedConnection {
  const SshSavedConnection({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.user,
    required this.authMethod,
    required this.connectTimeoutSeconds,
    required this.keepAliveSeconds,
    required this.createdAt,
    required this.updatedAt,
    this.identityFile,
    this.hostKeyType,
    this.hostKeyFingerprint,
    this.lastPath = '/',
    this.lastConnectedAt,
    this.favorite = false,
    this.tags = const <String>[],
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String user;
  final SshAuthMethod authMethod;
  final String? identityFile;
  final String? hostKeyType;
  final String? hostKeyFingerprint;
  final int connectTimeoutSeconds;
  final int keepAliveSeconds;
  final String lastPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastConnectedAt;
  final bool favorite;
  final List<String> tags;

  String get endpoint => '$user@$host:$port';

  List<String> validate() {
    final errors = <String>[];
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{1,63}$').hasMatch(id)) {
      errors.add('SSH connection ID is invalid.');
    }
    if (name.trim().isEmpty) errors.add('SSH connection name is required.');
    if (host.trim().isEmpty) errors.add('SSH host is required.');
    if (user.trim().isEmpty) errors.add('SSH user is required.');
    if (port < 1 || port > 65535) {
      errors.add('SSH port must be between 1 and 65535.');
    }
    if (authMethod.usesPrivateKey && (identityFile ?? '').trim().isEmpty) {
      errors.add('SSH private key file is required.');
    }
    if (connectTimeoutSeconds < 1 || connectTimeoutSeconds > 300) {
      errors.add('SSH timeout must be between 1 and 300 seconds.');
    }
    if (keepAliveSeconds < 0 || keepAliveSeconds > 3600) {
      errors.add('SSH keepalive must be between 0 and 3600 seconds.');
    }
    if (!lastPath.startsWith('/')) {
      errors.add('SSH last path must be an absolute POSIX path.');
    }
    return errors;
  }

  SourceConfig toSourceConfig({String? path}) => SourceConfig(
        type: SourceType.ssh,
        root: path ?? lastPath,
        host: host,
        user: user,
        port: port,
        identityFile: identityFile,
        sshAuthMethod: authMethod,
        sshHostKeyPolicy: hostKeyFingerprint == null
            ? SshHostKeyPolicy.trustOnFirstUse
            : SshHostKeyPolicy.pinned,
        hostKeyType: hostKeyType,
        hostKeyFingerprint: hostKeyFingerprint,
        connectTimeoutSeconds: connectTimeoutSeconds,
        keepAliveSeconds: keepAliveSeconds,
        sshConnectionId: id,
        sshConnectionName: name,
      );

  SshSavedConnection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? user,
    SshAuthMethod? authMethod,
    String? identityFile,
    String? hostKeyType,
    String? hostKeyFingerprint,
    int? connectTimeoutSeconds,
    int? keepAliveSeconds,
    String? lastPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastConnectedAt,
    bool? favorite,
    List<String>? tags,
  }) =>
      SshSavedConnection(
        id: id ?? this.id,
        name: name ?? this.name,
        host: host ?? this.host,
        port: port ?? this.port,
        user: user ?? this.user,
        authMethod: authMethod ?? this.authMethod,
        identityFile: identityFile ?? this.identityFile,
        hostKeyType: hostKeyType ?? this.hostKeyType,
        hostKeyFingerprint: hostKeyFingerprint ?? this.hostKeyFingerprint,
        connectTimeoutSeconds:
            connectTimeoutSeconds ?? this.connectTimeoutSeconds,
        keepAliveSeconds: keepAliveSeconds ?? this.keepAliveSeconds,
        lastPath: lastPath ?? this.lastPath,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
        favorite: favorite ?? this.favorite,
        tags: tags ?? this.tags,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'user': user,
        'authMethod': authMethod.wireName,
        if (identityFile != null) 'identityFile': identityFile,
        if (hostKeyType != null) 'hostKeyType': hostKeyType,
        if (hostKeyFingerprint != null)
          'hostKeyFingerprint': hostKeyFingerprint,
        'connectTimeoutSeconds': connectTimeoutSeconds,
        'keepAliveSeconds': keepAliveSeconds,
        'lastPath': lastPath,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (lastConnectedAt != null)
          'lastConnectedAt': lastConnectedAt!.toUtc().toIso8601String(),
        'favorite': favorite,
        'tags': tags,
      };

  factory SshSavedConnection.fromJson(Map<String, Object?> json) =>
      SshSavedConnection(
        id: json['id']! as String,
        name: json['name']! as String,
        host: json['host']! as String,
        port: json['port'] as int? ?? 22,
        user: json['user']! as String,
        authMethod: SshAuthMethodName.parse(
          json['authMethod'] as String? ?? 'password',
        ),
        identityFile: json['identityFile'] as String?,
        hostKeyType: json['hostKeyType'] as String?,
        hostKeyFingerprint: json['hostKeyFingerprint'] as String?,
        connectTimeoutSeconds: json['connectTimeoutSeconds'] as int? ?? 15,
        keepAliveSeconds: json['keepAliveSeconds'] as int? ?? 10,
        lastPath: json['lastPath'] as String? ?? '/',
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
        lastConnectedAt: json['lastConnectedAt'] == null
            ? null
            : DateTime.parse(json['lastConnectedAt']! as String),
        favorite: json['favorite'] as bool? ?? false,
        tags: (json['tags'] as List<Object?>? ?? const <Object?>[])
            .cast<String>(),
      );
}

class SshConnectionStore {
  SshConnectionStore(
    this.paths, {
    AtomicFileWriter writer = const AtomicFileWriter(),
    DateTime Function()? clock,
  })  : _writer = writer,
        _clock = clock ?? DateTime.now;

  final CentraPaths paths;
  final AtomicFileWriter _writer;
  final DateTime Function() _clock;

  Future<List<SshSavedConnection>> list() async {
    await paths.ensure();
    if (!await paths.sshConnectionsFile.exists()) {
      return const <SshSavedConnection>[];
    }
    final json = decodeJsonObject(
      await paths.sshConnectionsFile.readAsString(),
    );
    if (json['schema'] != 'centra.ssh-connections.v1') {
      throw FormatException(
        'Unsupported SSH connection library schema: ${json['schema']}',
      );
    }
    final values = (json['connections'] as List<Object?>? ?? const <Object?>[])
        .map(
          (value) => SshSavedConnection.fromJson(
            (value! as Map).cast<String, Object?>(),
          ),
        )
        .toList(growable: false);
    for (final connection in values) {
      final errors = connection.validate();
      if (errors.isNotEmpty) {
        throw FormatException(
          'Invalid saved SSH connection ${connection.id}: '
          '${errors.join(' ')}',
        );
      }
    }
    final sorted = List<SshSavedConnection>.from(values)
      ..sort((left, right) {
        if (left.favorite != right.favorite) return left.favorite ? -1 : 1;
        final leftUsed = left.lastConnectedAt;
        final rightUsed = right.lastConnectedAt;
        if (leftUsed != null || rightUsed != null) {
          if (leftUsed == null) return 1;
          if (rightUsed == null) return -1;
          final recent = rightUsed.compareTo(leftUsed);
          if (recent != 0) return recent;
        }
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
    return sorted;
  }

  Future<SshSavedConnection?> load(String id) async {
    final values = await list();
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }

  Future<void> save(SshSavedConnection connection) async {
    final errors = connection.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    final values = await list();
    final updated = <SshSavedConnection>[
      for (final value in values)
        if (value.id != connection.id) value,
      connection,
    ];
    await _write(updated);
  }

  Future<SshSavedConnection> create({
    required String name,
    required String host,
    required int port,
    required String user,
    required SshAuthMethod authMethod,
    String? identityFile,
    int connectTimeoutSeconds = 15,
    int keepAliveSeconds = 10,
    String lastPath = '/',
  }) async {
    final now = _clock().toUtc();
    final baseId = slugifySshConnectionName(name);
    final existing = (await list()).map((value) => value.id).toSet();
    var id = baseId;
    var suffix = 2;
    while (existing.contains(id)) {
      id = '$baseId-$suffix';
      suffix++;
    }
    final trimmedIdentity = identityFile?.trim();
    final connection = SshSavedConnection(
      id: id,
      name: name.trim(),
      host: host.trim(),
      port: port,
      user: user.trim(),
      authMethod: authMethod,
      identityFile:
          trimmedIdentity == null || trimmedIdentity.isEmpty ? null : trimmedIdentity,
      connectTimeoutSeconds: connectTimeoutSeconds,
      keepAliveSeconds: keepAliveSeconds,
      lastPath: lastPath,
      createdAt: now,
      updatedAt: now,
    );
    await save(connection);
    return connection;
  }

  Future<SshSavedConnection> duplicate(
    String id, {
    required String name,
  }) async {
    final source = await load(id);
    if (source == null) throw FormatException('SSH connection not found: $id');
    return create(
      name: name,
      host: source.host,
      port: source.port,
      user: source.user,
      authMethod: source.authMethod,
      identityFile: source.identityFile,
      connectTimeoutSeconds: source.connectTimeoutSeconds,
      keepAliveSeconds: source.keepAliveSeconds,
      lastPath: source.lastPath,
    );
  }

  Future<void> recordSuccessfulConnection({
    required SshSavedConnection connection,
    required String path,
    required String hostKeyType,
    required String hostKeyFingerprint,
  }) async {
    final now = _clock().toUtc();
    await save(
      connection.copyWith(
        lastPath: path,
        hostKeyType: hostKeyType,
        hostKeyFingerprint: hostKeyFingerprint,
        lastConnectedAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<bool> delete(String id) async {
    final values = await list();
    final updated = values.where((value) => value.id != id).toList();
    if (updated.length == values.length) return false;
    await _write(updated);
    return true;
  }

  Future<void> _write(List<SshSavedConnection> values) async {
    await paths.ensure();
    final sorted = List<SshSavedConnection>.from(values)
      ..sort((left, right) => left.id.compareTo(right.id));
    await _writer.writeText(
      paths.sshConnectionsFile,
      '${prettyJson(<String, Object?>{
        'schema': 'centra.ssh-connections.v1',
        'connections': sorted
            .map((connection) => connection.toJson())
            .toList(growable: false),
      })}\n',
    );
  }
}

String slugifySshConnectionName(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^[-._]+|[-._]+$'), '');
  final base = normalized.isEmpty ? 'ssh-connection' : normalized;
  return base.length <= 64 ? base : base.substring(0, 64);
}
