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
        remotePort: 28001,
        localPort: 1234,
        password: '',
        preset: UdpSpeederPreset.normal,
        mode: 1,
        timeout: 5,
        mtu: 1250,
      ),
      udp2rawConfig: Udp2RawConfig(
        serverIp: wg.serverHost,
        remotePort: 8080,
        localPort: 1234,
        password: 'selcuk05',
        rawMode: RawMode.faketcp,
      ),
    );
  }

  VpnProfile _createSampleProfile() {
    const sampleWg = '''[Interface]
PrivateKey = wFtflSQvAA2WWDMuqj640oXtZTK8cdasZgphk3CME3A=
Address = 10.13.13.9/32
DNS = 1.1.1.1, 8.8.8.8
MTU = 1250

[Peer]
PublicKey = vtEXS//3XH3aauDJdocDPFZhqf48GlLlH1pbBwnZ1y0=
PresharedKey = yb+RIpi+4wdhqT8uAQhtRVY9yvc6laqnwx6/dO0bew0=
Endpoint = selcuk9805.keenetic.pro:51820
AllowedIPs = 10.13.13.0/24
PersistentKeepalive = 25''';

    final wg = WireGuardConfig.parse(sampleWg);

    return VpnProfile(
      id: 'default-profile-1',
      name: 'Selcuk Keenetic Server',
      tunnelMode: TunnelMode.udpspeeder,
      wireGuardConfig: wg,
      udpSpeederConfig: const UdpSpeederConfig(
        serverIp: 'selcuk9805.keenetic.pro',
        remotePort: 28001,
        localPort: 1234,
        password: '',
        preset: UdpSpeederPreset.normal,
        mode: 1,
        timeout: 5,
        mtu: 1250,
      ),
      udp2rawConfig: const Udp2RawConfig(
        serverIp: 'selcuk9805.keenetic.pro',
        remotePort: 8080,
        localPort: 1234,
        password: 'selcuk05',
        rawMode: RawMode.faketcp,
        cipherMode: CipherMode.aes128cbc,
        seqMode: 3,
        fixGro: true,
      ),
    );
  }
}
