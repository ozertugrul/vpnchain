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

    ObfuscationEngine engine;

    if (profile.tunnelMode == TunnelMode.udpspeeder) {
      if (preference == EnginePreference.native) {
        final args = profile.udpSpeederConfig.buildCliParams().split(' ');
        engine = NativeProcessEngine(
          binaryName: 'speederv2',
          arguments: args,
          customBinaryPath: customBinaryPath,
        );
      } else {
        // Built-in pure Dart engine
        engine = BuiltInUdpSpeederEngine(config: profile.udpSpeederConfig);
      }
    } else {
      // udp2raw mode
      if (preference == EnginePreference.native) {
        final args = profile.udp2rawConfig.buildCliParams().split(' ');
        engine = NativeProcessEngine(
          binaryName: 'udp2raw',
          arguments: args,
          customBinaryPath: customBinaryPath,
        );
      } else {
        // Built-in pure Dart engine
        engine = BuiltInUdp2RawEngine(config: profile.udp2rawConfig);
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
        onLog('Native process failed. Falling back to Built-in Dart engine...');
        if (profile.tunnelMode == TunnelMode.udpspeeder) {
          engine = BuiltInUdpSpeederEngine(config: profile.udpSpeederConfig);
        } else {
          engine = BuiltInUdp2RawEngine(config: profile.udp2rawConfig);
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

  Future<void> stop() async {
    if (_activeEngine != null) {
      await _activeEngine!.stop();
      _activeEngine = null;
    }
  }
}
