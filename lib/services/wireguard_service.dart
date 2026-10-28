import 'dart:async';
import 'package:wireguard_flutter_plus/wireguard_flutter_plus.dart';
import '../models/vpn_stats.dart';

class WireGuardService {
  final _wireGuard = WireGuardFlutter.instance;
  bool _initialized = false;

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

  Future<void> start({
    required String wgConfigText,
    required String serverAddress,
    String? providerBundleIdentifier,
    required Function(VpnStatus status) onStatusChanged,
    required Function(int rxSpeed, int txSpeed, int totalRx, int totalTx) onTrafficUpdate,
    required Function(String log) onLog,
  }) async {
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
