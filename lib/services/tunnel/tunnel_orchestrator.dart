import 'dart:io';
import '../../models/tunnel_mode.dart';
import '../../models/vpn_profile.dart';
import 'builtin_udpspeeder_engine.dart';
import 'builtin_udp2raw_engine.dart';
import 'native_process_engine.dart';
import 'obfuscation_engine.dart';

enum EnginePreference { auto, builtin, native }

class TunnelOrchestrator {
  ObfuscationEngine? _activeEngine;

  ObfuscationEngine? get activeEngine => _activeEngine;
  bool get isRunning => _activeEngine?.isRunning ?? false;

  Future<void> start({
    required VpnProfile profile,
    EnginePreference preference = EnginePreference.auto,
    String? customBinaryPath,
    required Function(String log) onLog,
    required Function(dynamic error) onError,
    Function(int bytesSent, int bytesReceived, bool isHandshake, bool isReply)? onPacketActivity,
  }) async {
    await stop();

    if (profile.tunnelMode == TunnelMode.direct) {
      onLog('Direct WireGuard mode selected. Obfuscation bypass active.');
      return;
    }

    // 1. Resolve domain name to numeric IPv4/IPv6 address
    String resolvedServerIp = profile.activeServerIp;
    try {
      final lookup = await InternetAddress.lookup(profile.activeServerIp);
      if (lookup.isNotEmpty) {
        resolvedServerIp = lookup.first.address;
        onLog('Resolved server host "${profile.activeServerIp}" -> $resolvedServerIp');
      }
    } catch (e) {
      onLog('Warning: Could not resolve hostname "${profile.activeServerIp}": $e. Using as-is.');
    }

    ObfuscationEngine engine;

    if (profile.tunnelMode == TunnelMode.udpspeeder) {
      final speederConfig = profile.udpSpeederConfig.copyWith(serverIp: resolvedServerIp);
      final args = speederConfig.buildCliParamsList(resolvedIp: resolvedServerIp);

      final nativeEngine = NativeProcessEngine(
        binaryName: 'speederv2',
        arguments: args,
        customBinaryPath: customBinaryPath,
      );

      // Check if native binary exists
      final nativeAvailable = (preference == EnginePreference.native) ||
          (preference == EnginePreference.auto && await _isNativeExecutable(nativeEngine));

      if (nativeAvailable) {
        engine = nativeEngine;
      } else {
        // Built-in pure Dart engine
        engine = BuiltInUdpSpeederEngine(config: speederConfig);
      }
    } else {
      // udp2raw mode
      final rawConfig = profile.udp2rawConfig.copyWith(serverIp: resolvedServerIp);
      final args = rawConfig.buildCliParamsList(resolvedIp: resolvedServerIp);

      final nativeEngine = NativeProcessEngine(
        binaryName: 'udp2raw',
        arguments: args,
        customBinaryPath: customBinaryPath,
      );

      final nativeAvailable = (preference == EnginePreference.native) ||
          (preference == EnginePreference.auto && await _isNativeExecutable(nativeEngine));

      if (nativeAvailable) {
        engine = nativeEngine;
      } else {
        // Built-in pure Dart engine
        engine = BuiltInUdp2RawEngine(config: rawConfig);
      }
    }

    _activeEngine = engine;
    onLog('Launching obfuscation engine: ${engine.engineName}');

    try {
      await engine.start(
        onLog: onLog,
        onError: onError,
        onPacketActivity: onPacketActivity,
      );
    } catch (e) {
      // If native failed, try fallback to built-in if preference was auto
      if (preference == EnginePreference.auto && engine is NativeProcessEngine) {
        onLog('Native process failed ($e). Falling back to Built-in Dart engine...');
        if (profile.tunnelMode == TunnelMode.udpspeeder) {
          engine = BuiltInUdpSpeederEngine(config: profile.udpSpeederConfig.copyWith(serverIp: resolvedServerIp));
        } else {
          engine = BuiltInUdp2RawEngine(config: profile.udp2rawConfig.copyWith(serverIp: resolvedServerIp));
        }
        _activeEngine = engine;
        await engine.start(
          onLog: onLog,
          onError: onError,
          onPacketActivity: onPacketActivity,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<bool> _isNativeExecutable(NativeProcessEngine engine) async {
    try {
      final path = await engine.findBinaryPath();
      return path != null && path.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    if (_activeEngine != null) {
      await _activeEngine!.stop();
      _activeEngine = null;
    }
  }
}
