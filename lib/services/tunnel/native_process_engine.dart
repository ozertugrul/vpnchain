import 'dart:convert';
import 'dart:io';
import 'obfuscation_engine.dart';

class NativeProcessEngine implements ObfuscationEngine {
  final String binaryName; // e.g. "speederv2" or "udp2raw"
  final List<String> arguments;
  final String? customBinaryPath;

  Process? _process;
  bool _running = false;

  NativeProcessEngine({
    required this.binaryName,
    required this.arguments,
    this.customBinaryPath,
  });

  @override
  bool get isRunning => _running;

  @override
  String get engineName => 'Native CLI Process ($binaryName)';

  @override
  Future<void> start({
    required Function(String log) onLog,
    required Function(dynamic error) onError,
    Function(int bytesSent, int bytesReceived, bool isHandshake, bool isReply)? onPacketActivity,
  }) async {
    if (_running) return;

    final resolvedPath = await _findBinaryPath();
    if (resolvedPath == null) {
      throw FileNotFoundException(
        'Native binary "$binaryName" not found. Please install it or use the Built-in Dart Core engine.',
      );
    }

    try {
      onLog('Starting native process: $resolvedPath ${arguments.join(" ")}');

      _process = await Process.start(
        resolvedPath,
        arguments,
        mode: ProcessStartMode.normal,
      );
      _running = true;

      // Stream standard output
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.trim().isNotEmpty) {
          onLog('[$binaryName] $line');
        }
      });

      // Stream standard error
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.trim().isNotEmpty) {
          onLog('[$binaryName stderr] $line');
        }
      });

      _process!.exitCode.then((code) {
        onLog('[$binaryName] Process exited with code $code');
        _running = false;
        _process = null;
      });
    } catch (e) {
      _running = false;
      await stop();
      onError(e);
      rethrow;
    }
  }

  Future<String?> _findBinaryPath() async {
    if (customBinaryPath != null && File(customBinaryPath!).existsSync()) {
      return customBinaryPath;
    }

    // Check application directory
    final currentDir = Directory.current.path;
    final exeExt = Platform.isWindows ? '.exe' : '';
    final localFile = File('$currentDir/$binaryName$exeExt');
    if (localFile.existsSync()) {
      return localFile.path;
    }

    // Check system PATH
    final pathEnv = Platform.environment['PATH'] ?? '';
    final separator = Platform.isWindows ? ';' : ':';
    for (final dir in pathEnv.split(separator)) {
      final file = File('$dir/$binaryName$exeExt');
      if (file.existsSync()) {
        return file.path;
      }
    }

    return null;
  }

  @override
  Future<void> stop() async {
    _running = false;
    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
      _process = null;
    }
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);

  @override
  String toString() => message;
}
