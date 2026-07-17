import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cinder/cinder.dart';
import 'package:dartssh2/dartssh2.dart';

import '../core/ssh_connection.dart';

/// Adapts a remote SSH shell to Cinder's terminal controller contract.
///
/// No local shell or external SSH executable is started. Input, output, and
/// terminal resize events are carried over the already authenticated SSH
/// transport.
class SshTerminalController extends PtyController {
  SshTerminalController({
    required this.connection,
    this.maximumBufferedLines = 10000,
  }) : super(command: 'ssh', maxBufferLines: maximumBufferedLines);

  final SshConnection connection;
  final int maximumBufferedLines;

  final List<void Function(String)> _outputCallbacks = <void Function(String)>[];
  final List<void Function(int)> _exitCallbacks = <void Function(int)>[];
  final List<void Function(Object)> _errorCallbacks = <void Function(Object)>[];
  final List<VoidCallback> _listeners = <VoidCallback>[];
  final List<String> _buffer = <String>[];

  SSHSession? _session;
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  PtyStatus _remoteStatus = PtyStatus.notStarted;
  int _rows = 24;
  int _columns = 80;
  int? _exitCode;
  bool _exitReported = false;

  @override
  PtyStatus get status => _remoteStatus;

  @override
  bool get isRunning => _remoteStatus == PtyStatus.running;

  @override
  int? get pid => null;

  @override
  int? get exitCode => _exitCode;

  @override
  int get rows => _rows;

  @override
  int get columns => _columns;

  @override
  List<String> get outputBuffer => List<String>.unmodifiable(_buffer);

  @override
  Future<void> start({required int columns, required int rows}) async {
    if (isRunning || _remoteStatus == PtyStatus.starting) {
      throw StateError('SSH terminal is already running.');
    }
    _columns = columns;
    _rows = rows;
    _exitCode = null;
    _exitReported = false;
    _remoteStatus = PtyStatus.starting;
    _notify();
    try {
      final session = await connection.openShell(columns: columns, rows: rows);
      _session = session;
      _stdoutSubscription = session.stdout.listen(
        (bytes) => _emit(utf8.decode(bytes, allowMalformed: true)),
        onError: _reportError,
        onDone: () => _reportExit(0),
      );
      _stderrSubscription = session.stderr.listen(
        (bytes) => _emit(utf8.decode(bytes, allowMalformed: true)),
        onError: _reportError,
      );
      _remoteStatus = PtyStatus.running;
      _notify();
    } on Object catch (error) {
      _remoteStatus = PtyStatus.error;
      _exitCode = -1;
      _reportError(error);
      rethrow;
    }
  }

  @override
  void write(String data) {
    if (!isRunning) throw StateError('SSH terminal is not running.');
    _session!.write(utf8.encode(data));
  }

  @override
  void writeBytes(List<int> bytes) {
    if (!isRunning) throw StateError('SSH terminal is not running.');
    _session!.write(bytes);
  }

  @override
  void resize(int columns, int rows) {
    if (!isRunning) return;
    _columns = columns;
    _rows = rows;
    _session?.resizeTerminal(columns, rows);
    _notify();
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!isRunning && _remoteStatus != PtyStatus.starting) return false;
    _session?.close();
    _reportExit(0);
    return true;
  }

  @override
  void clearBuffer() {
    _buffer.clear();
    _notify();
  }

  @override
  Future<void> restart() async {
    await _closeSession(reportExit: false);
    _remoteStatus = PtyStatus.notStarted;
    await start(columns: _columns, rows: _rows);
  }

  @override
  void addOutputCallback(void Function(String) callback) {
    _outputCallbacks.add(callback);
  }

  @override
  void removeOutputCallback(void Function(String) callback) {
    _outputCallbacks.remove(callback);
  }

  @override
  void addExitCallback(void Function(int) callback) {
    _exitCallbacks.add(callback);
  }

  @override
  void removeExitCallback(void Function(int) callback) {
    _exitCallbacks.remove(callback);
  }

  @override
  void addErrorCallback(void Function(Object) callback) {
    _errorCallbacks.add(callback);
  }

  @override
  void removeErrorCallback(void Function(Object) callback) {
    _errorCallbacks.remove(callback);
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  Future<void> dispose() async {
    await _closeSession(reportExit: false);
    _remoteStatus = PtyStatus.disposed;
    _outputCallbacks.clear();
    _exitCallbacks.clear();
    _errorCallbacks.clear();
    _listeners.clear();
  }

  void _emit(String data) {
    if (data.isEmpty) return;
    _buffer.addAll(data.split('\n'));
    while (_buffer.length > maximumBufferedLines) {
      _buffer.removeAt(0);
    }
    for (final callback in List<void Function(String)>.of(_outputCallbacks)) {
      callback(data);
    }
    _notify();
  }

  void _reportError(Object error) {
    for (final callback in List<void Function(Object)>.of(_errorCallbacks)) {
      callback(error);
    }
    _notify();
  }

  void _reportExit(int code) {
    if (_exitReported) return;
    _exitReported = true;
    _exitCode = code;
    _remoteStatus = PtyStatus.exited;
    for (final callback in List<void Function(int)>.of(_exitCallbacks)) {
      callback(code);
    }
    _notify();
  }

  Future<void> _closeSession({required bool reportExit}) async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _session?.close();
    _session = null;
    if (reportExit) _reportExit(0);
  }

  void _notify() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }
}
