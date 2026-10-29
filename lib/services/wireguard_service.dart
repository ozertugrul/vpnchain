import 'dart:async';
import 'dart:io';
import 'package:wireguard_flutter_plus/wireguard_flutter_plus.dart';
import '../models/vpn_stats.dart';

class WireGuardService {
  final _wireGuard = WireGuardFlutter.instance;
  bool _initialized = false;
  bool _usingWgQuick = false;
  static const String _confPath = '/tmp/vpnchain0.conf';

  StreamSubscription? _stageSub;
  StreamSubscription? _trafficSub;

  Future<void> initialize({
    String interfaceName = 'vpnchain0',
    String vpnName = 'VPNChain',
  }) async {
    if (_initialized) return;

    try {
      await _wireGuard.initialize(
        interfaceName: interfaceName,
        vpnName: vpnName,
      );
      _initialized = true;
    } catch (e) {
      // On platforms where native WireGuard is not yet registered (e.g. macOS dev mode without NetworkExtension)
      // we log and mark initialized
      _initialized = true;
    }
  }

  String? _findWgQuick() {
    for (final p in ['/opt/homebrew/bin/wg-quick', '/usr/local/bin/wg-quick', '/usr/bin/wg-quick']) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }

  Future<void> start({
    required String wgConfigText,
    required String serverAddress,
    String? providerBundleIdentifier,
    required Function(VpnStatus status) onStatusChanged,
    required Function(int rxSpeed, int txSpeed, int totalRx, int totalTx) onTrafficUpdate,
    required Function(String log) onLog,
  }) async {
    // 1. On macOS desktop, prioritize native wg-quick if available to bypass Apple NetworkExtension restrictions
    if (Platform.isMacOS) {
      final wgQuick = _findWgQuick();
      if (wgQuick != null) {
        onLog('macOS: Detected native wg-quick at $wgQuick');
        try {
          final confFile = File(_confPath);
          await confFile.writeAsString(wgConfigText);

          onLog('macOS: Requesting system permission to activate tunnel...');
          const envPath = 'export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH;';
          // Tear down any stale interface first
          await Process.run('osascript', [
            '-e',
            'do shell script "$envPath $wgQuick down $_confPath 2>/dev/null || true" with administrator privileges',
          ]);

          final result = await Process.run('osascript', [
            '-e',
            'do shell script "$envPath $wgQuick up $_confPath" with administrator privileges',
          ]);

          if (result.exitCode == 0) {
            _usingWgQuick = true;
            onLog('macOS: Native WireGuard tunnel activated successfully!');
            onLog(result.stdout.toString().trim());
            onStatusChanged(VpnStatus.connected);
            return;
          } else {
            final err = result.stderr.toString().trim();
            onLog('macOS: wg-quick up failed: $err');
            throw Exception('macOS wg-quick failed to activate tunnel: $err');
          }
        } catch (e) {
          onLog('macOS: wg-quick launcher note: $e');
          rethrow;
        }
      }
    }

    // 2. Standard WireGuard plugin initialization (Windows, Android, iOS, or macOS extension)
    await initialize();

    _stageSub?.cancel();
    _trafficSub?.cancel();

    // Listen to native stage updates
    try {
      _stageSub = _wireGuard.vpnStageSnapshot.listen((stage) {
        onLog('[WireGuard Stage] $stage');
        switch (stage.toString().toLowerCase()) {
          case 'connected':
            onStatusChanged(VpnStatus.connected);
            break;
          case 'connecting':
            onStatusChanged(VpnStatus.connecting);
            break;
          case 'disconnected':
          case 'stopped':
            onStatusChanged(VpnStatus.disconnected);
            break;
          case 'denied':
          case 'error':
            onStatusChanged(VpnStatus.error);
            break;
        }
      });
    } catch (e) {
      onLog('[WireGuard] Stage listener setup error: $e');
    }

    // Listen to real-time traffic updates
    try {
      _trafficSub = _wireGuard.trafficSnapshot.listen((data) {
        final rxSpeed = _parseBytes(data['downloadSpeed']);
        final txSpeed = _parseBytes(data['uploadSpeed']);
        final totalRx = _parseBytes(data['totalDownload']);
        final totalTx = _parseBytes(data['totalUpload']);

        onTrafficUpdate(rxSpeed, txSpeed, totalRx, totalTx);
      });
    } catch (e) {
      onLog('[WireGuard] Traffic listener setup error: $e');
    }

    try {
      onLog('Starting WireGuard interface...');
      await _wireGuard.startVpn(
        serverAddress: serverAddress,
        wgQuickConfig: wgConfigText,
        providerBundleIdentifier: providerBundleIdentifier ?? 'com.vpnchain.vpnchain.WGExtension',
      );
    } catch (e) {
      onLog('[WireGuard Error] $e');
      rethrow;
    }
  }

  Future<void> stop({required Function(String log) onLog}) async {
    if (_usingWgQuick && Platform.isMacOS) {
      final wgQuick = _findWgQuick();
      if (wgQuick != null) {
        try {
          onLog('macOS: Tearing down wg-quick interface...');
          const envPath = 'export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH;';
          await Process.run('osascript', [
            '-e',
            'do shell script "$envPath $wgQuick down $_confPath 2>/dev/null || true" with administrator privileges',
          ]);
          _usingWgQuick = false;
          onLog('macOS: wg-quick tunnel terminated.');
          return;
        } catch (e) {
          onLog('macOS: wg-quick down error: $e');
        }
      }
    }

    try {
      _stageSub?.cancel();
      _trafficSub?.cancel();
      await _wireGuard.stopVpn();
      onLog('WireGuard interface stopped.');
    } catch (e) {
      onLog('[WireGuard] Stop error: $e');
    }
  }

  int _parseBytes(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
