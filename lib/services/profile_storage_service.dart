import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tunnel_mode.dart';
import '../models/vpn_profile.dart';
import '../models/wireguard_config.dart';
import '../models/udpspeeder_config.dart';
import '../models/udp2raw_config.dart';

class ProfileStorageService {
  static const String _keyProfiles = 'vpnchain_profiles_v1';
  static const String _keyActiveProfileId = 'vpnchain_active_profile_id';

  Future<List<VpnProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyProfiles);

    if (jsonStr == null || jsonStr.trim().isEmpty) {
      // Seed initial default profile
      final defaultProfile = _createSampleProfile();
      await saveProfiles([defaultProfile]);
      await setActiveProfileId(defaultProfile.id);
      return [defaultProfile];
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => VpnProfile.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // Fallback
      return [_createSampleProfile()];
    }
  }

  Future<void> saveProfiles(List<VpnProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_keyProfiles, encoded);
  }

  Future<String?> getActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActiveProfileId);
  }

  Future<void> setActiveProfileId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveProfileId, id);
  }

  /// Imports from JSON string (supports both modern .vpnchain and legacy .selconf)
  List<VpnProfile> importFromJson(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return [];

    final dynamic parsed = jsonDecode(trimmed);
    if (parsed is List) {
      return parsed.map((e) => VpnProfile.fromJson(e as Map<String, dynamic>)).toList();
    } else if (parsed is Map<String, dynamic>) {
      return [VpnProfile.fromJson(parsed)];
    }
    return [];
  }

  /// Imports from standard WireGuard .conf text
  VpnProfile importFromWireGuardConf(String confText, {String name = 'Imported WireGuard'}) {
    final wg = WireGuardConfig.parse(confText);
    return VpnProfile(
      name: name,
      tunnelMode: TunnelMode.udpspeeder,
      wireGuardConfig: wg,
      udpSpeederConfig: UdpSpeederConfig(
        serverIp: wg.serverHost,
        remotePort: 4096,
        localPort: 1234,
      ),
      udp2rawConfig: Udp2RawConfig(
        serverIp: wg.serverHost,
        remotePort: 4097,
        localPort: 1234,
      ),
    );
  }

  VpnProfile _createSampleProfile() {
    const sampleWg = '''[Interface]
PrivateKey = aGE2c2RrZmxqYXNkZmxramFzZGZsa2phc2RmbGtmYXNkYXM=
Address = 10.13.13.2/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1280

[Peer]
PublicKey = YmFzZTY0cHVibGlja2V5ZXhhbXBsZTFhMjM0NTY3ODkwMTI=
Endpoint = 198.51.100.1:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25''';

    final wg = WireGuardConfig.parse(sampleWg);

    return VpnProfile(
      id: 'default-profile-1',
      name: 'Default Chained Server',
      tunnelMode: TunnelMode.udpspeeder,
      wireGuardConfig: wg,
      udpSpeederConfig: const UdpSpeederConfig(
        serverIp: '198.51.100.1',
        remotePort: 4096,
        localPort: 1234,
        password: 'vpnchain_secret',
        preset: UdpSpeederPreset.fec1_2,
        mode: 1,
        timeout: 5,
        mtu: 1280,
      ),
      udp2rawConfig: const Udp2RawConfig(
        serverIp: '198.51.100.1',
        remotePort: 4097,
        localPort: 1234,
        password: 'vpnchain_secret',
        rawMode: RawMode.faketcp,
        cipherMode: CipherMode.aes128cbc,
        seqMode: 3,
        fixGro: true,
      ),
    );
  }
}
