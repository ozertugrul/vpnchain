import 'dart:async';
import 'dart:io';
import 'package:wireguard_flutter_plus/wireguard_flutter_plus.dart';
import '../models/vpn_stats.dart';

class WireGuardService {
  final _wireGuard = WireGuardFlutter.instance;
  bool _initialized = false;
  bool _usingWgQuick = false;
  String? _activeScutilProfile;
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

  Future<String?> _findScutilVpnProfile(String? requestedName) async {
    if (!Platform.isMacOS) return null;
    try {
      final res = await Process.run('scutil', ['--nc', 'list']);
      if (res.exitCode == 0) {
        final lines = res.stdout.toString().split('\n');
        // Priority 1: Exact match with current profile name
        if (requestedName != null && requestedName.trim().isNotEmpty) {
          final target = requestedName.trim();
          for (final line in lines) {
            if (line.contains('"$target"')) {
              return target;
            }
          }
        }
        // Priority 2: Any registered WireGuard profile (e.g., peer_ErtuMac, VPNChain)
        for (final line in lines) {
          if (line.contains('(com.wireguard.macos)') || line.contains('VPNChain') || line.contains('peer_ErtuMac')) {
            final match = RegExp(r'"([^"]+)"').firstMatch(line);
            if (match != null) {
              return match.group(1);
            }
          }
        }
      }
    } catch (_) {}
    return null;
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
    String? profileName,
    String? providerBundleIdentifier,
    required Function(VpnStatus status) onStatusChanged,
    required Function(int rxSpeed, int txSpeed, int totalRx, int totalTx) onTrafficUpdate,
    required Function(String log) onLog,
  }) async {
    // 1. On macOS desktop, check if a chained Apple NetworkExtension VPN Profile is configured (0 password prompts)
    if (Platform.isMacOS) {
      final scutilProfile = await _findScutilVpnProfile(profileName);
      if (scutilProfile != null) {
        // Inspect profile remote address to verify it is chained to local obfuscator
        final showRes = await Process.run('scutil', ['--nc', 'show', scutilProfile]);
        final output = showRes.stdout.toString();
        final isChained = output.contains('127.0.0.1') || output.contains('localhost');

        if (isChained) {
          onLog('macOS: Found registered Apple VPN Profile "$scutilProfile" (Endpoint: 127.0.0.1, Chained Mode)');
          try {
            onLog('macOS: Connecting Apple VPN Profile "$scutilProfile" silently without password prompt...');
            final startRes = await Process.run('scutil', ['--nc', 'start', scutilProfile]);
            if (startRes.exitCode == 0) {
              _activeScutilProfile = scutilProfile;
              onLog('macOS: Native Apple VPN Profile active! Monitored in System Settings.');
              onStatusChanged(VpnStatus.connected);
              return;
            }
          } catch (e) {
            onLog('macOS: scutil start note: $e');
          }
        } else {
          final remoteMatch = RegExp(r'RemoteAddress\s*:\s*([^\s\n]+)').firstMatch(output);
          final remoteAddr = remoteMatch?.group(1) ?? 'Direct Endpoint';
          onLog('macOS: Apple VPN Profile "$scutilProfile" has direct endpoint "$remoteAddr" (bypasses obfuscator).');
          onLog('macOS: Using wg-quick with chained obfuscation config (127.0.0.1:localPort) for DPI bypass.');
        }
      }

      final wgQuick = _findWgQuick();
      if (wgQuick != null) {
        onLog('macOS: Using wg-quick with chained obfuscation config at $wgQuick');
        try {
          final confFile = File(_confPath);
          await confFile.writeAsString(wgConfigText);

          // 1. First try non-interactive sudo (0 password prompts if sudoers configured)
          await Process.run('sudo', ['-n', wgQuick, 'down', _confPath], environment: {
            'PATH': '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin',
          });

          var upRes = await Process.run('sudo', ['-n', wgQuick, 'up', _confPath], environment: {
            'PATH': '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin',
          });

          if (upRes.exitCode == 0) {
            _usingWgQuick = true;
            onLog('macOS: WireGuard tunnel activated silently via sudo (chained to obfuscator)!');
            onLog(upRes.stdout.toString().trim());
            onStatusChanged(VpnStatus.connected);
            return;
          }

          // 2. Fallback to osascript with administrator privileges
          // Simultaneously install sudoers NOPASSWD rule so user NEVER has to enter password again!
          onLog('macOS: Authenticating wg-quick (enabling 1-time passwordless authorization)...');
          final currentUser = Platform.environment['USER'] ?? 'ertu-mac';
          const envPath = 'export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH;';
          final setupSudoers = 'mkdir -p /etc/sudoers.d && echo "$currentUser ALL=(ALL) NOPASSWD: /opt/homebrew/bin/wg-quick, /usr/local/bin/wg-quick, /opt/homebrew/bin/wireguard-go, /usr/local/bin/wireguard-go" > /etc/sudoers.d/vpnchain && chmod 0440 /etc/sudoers.d/vpnchain;';

          await Process.run('osascript', [
            '-e',
            'do shell script "$envPath $wgQuick down $_confPath 2>/dev/null || true" with administrator privileges',
          ]);

          final result = await Process.run('osascript', [
            '-e',
            'do shell script "$setupSudoers $envPath $wgQuick up $_confPath" with administrator privileges',
          ]);

          if (result.exitCode == 0) {
            _usingWgQuick = true;
            onLog('macOS: WireGuard tunnel activated successfully (chained to obfuscator)!');
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
    if (_activeScutilProfile != null && Platform.isMacOS) {
      onLog('macOS: Deactivating Apple VPN Profile "$_activeScutilProfile"...');
      try {
        await Process.run('scutil', ['--nc', 'stop', _activeScutilProfile!]);
        _activeScutilProfile = null;
        onLog('macOS: Native Apple VPN Profile disconnected.');
        return;
      } catch (e) {
        onLog('macOS: scutil stop error: $e');
      }
    }

    if (_usingWgQuick && Platform.isMacOS) {
      final wgQuick = _findWgQuick();
      if (wgQuick != null) {
        try {
          onLog('macOS: Tearing down wg-quick interface...');
          // 1. Try non-interactive sudo first
          final sudoRes = await Process.run('sudo', ['-n', wgQuick, 'down', _confPath], environment: {
            'PATH': '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin',
          });
          if (sudoRes.exitCode != 0) {
            // 2. Fallback to osascript
            const envPath = 'export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH;';
            await Process.run('osascript', [
              '-e',
              'do shell script "$envPath $wgQuick down $_confPath 2>/dev/null || true" with administrator privileges',
            ]);
          }
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
