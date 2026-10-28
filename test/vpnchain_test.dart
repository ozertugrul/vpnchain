import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnchain/models/tunnel_mode.dart';
import 'package:vpnchain/models/udpspeeder_config.dart';
import 'package:vpnchain/models/udp2raw_config.dart';
import 'package:vpnchain/models/vpn_profile.dart';
import 'package:vpnchain/models/wireguard_config.dart';

void main() {
  group('WireGuardConfig Tests', () {
    const rawConf = '''
[Interface]
PrivateKey = aGVsbG93b3JsZHByaXZhdGVrZXlleGFtcGxlMTIzNDU2Nzg=
Address = 10.8.0.2/24
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = c2VydmVycHVibGlja2V5ZXhhbXBsZTEyMzQ1Njc4OTA=
PresharedKey = cHJlc2hhcmVka2V5ZXhhbXBsZTEyMzQ1Njc4OTA=
Endpoint = 203.0.113.195:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
''';

    test('Parses INI config correctly', () {
      final config = WireGuardConfig.parse(rawConf);
      expect(config.isValid, isTrue);
      expect(config.privateKey, 'aGVsbG93b3JsZHByaXZhdGVrZXlleGFtcGxlMTIzNDU2Nzg=');
      expect(config.address, '10.8.0.2/24');
      expect(config.peerPublicKey, 'c2VydmVycHVibGlja2V5ZXhhbXBsZTEyMzQ1Njc4OTA=');
      expect(config.endpoint, '203.0.113.195:51820');
      expect(config.serverHost, '203.0.113.195');
      expect(config.serverPort, 51820);
    });

    test('Rewrites chained endpoint to 127.0.0.1:<localPort> and adjusts MTU to 1280', () {
      final config = WireGuardConfig.parse(rawConf);
      final chained = config.generateChainedConfig(localPort: 1234, targetMtu: 1280);

      expect(chained, contains('Endpoint = 127.0.0.1:1234'));
      expect(chained, contains('MTU = 1280'));
      expect(chained, isNot(contains('Endpoint = 203.0.113.195:51820')));
    });
  });

  group('UDPspeeder & udp2raw Config Tests', () {
    test('UDPspeeder CLI param generation', () {
      const config = UdpSpeederConfig(
        serverIp: '198.51.100.1',
        remotePort: 4096,
        localPort: 1234,
        password: 'my_secret_key',
        preset: UdpSpeederPreset.fec1_2,
        mode: 1,
        timeout: 5,
        mtu: 1280,
      );

      final cli = config.buildCliParams();
      expect(cli, contains('-c -l 127.0.0.1:1234 -r 198.51.100.1:4096'));
      expect(cli, contains('-k my_secret_key'));
      expect(cli, contains('-f1:2'));
      expect(cli, contains('--mode 1'));
      expect(cli, contains('--timeout 5'));
      expect(cli, contains('--mtu 1280'));
    });

    test('udp2raw CLI param generation with FakeTCP', () {
      const config = Udp2RawConfig(
        serverIp: '198.51.100.1',
        remotePort: 4097,
        localPort: 1234,
        password: 'my_secret_key',
        rawMode: RawMode.faketcp,
        cipherMode: CipherMode.aes128cbc,
        seqMode: 3,
        fixGro: true,
      );

      final cli = config.buildCliParams();
      expect(cli, contains('-c -l 127.0.0.1:1234 -r 198.51.100.1:4097'));
      expect(cli, contains('-k my_secret_key'));
      expect(cli, contains('--raw-mode faketcp'));
      expect(cli, contains('--cipher-mode aes128cbc'));
      expect(cli, contains('--seq-mode 3'));
      expect(cli, contains('--fix-gro'));
    });
  });

  group('Profile Backwards Compatibility', () {
    test('Loads legacy .selconf JSON format correctly', () {
      const legacyJson = '''
      {
        "id": "legacy-test-1",
        "name": "Friend Android Profile",
        "udpSpeederConfig": {
          "serverIp": "198.51.100.5",
          "remotePort": "4096",
          "localPort": "1234",
          "preset": "FEC"
        },
        "wireGuardConfig": {
          "rawConfigText": "[Interface]\\nPrivateKey = abc\\nAddress = 10.0.0.2\\n\\n[Peer]\\nPublicKey = def\\nEndpoint = 198.51.100.5:51820"
        }
      }
      ''';

      final profile = VpnProfile.fromJson(jsonDecode(legacyJson));
      expect(profile.name, 'Friend Android Profile');
      expect(profile.udpSpeederConfig.serverIp, '198.51.100.5');
      expect(profile.udpSpeederConfig.remotePort, 4096);
      expect(profile.udpSpeederConfig.preset, UdpSpeederPreset.fec1_2);
      expect(profile.wireGuardConfig.serverHost, '198.51.100.5');
    });

    test('Exports and imports modern .vpnchain profile format seamlessly', () {
      final original = VpnProfile(
        name: 'Production Chained VPN',
        tunnelMode: TunnelMode.udp2raw,
        wireGuardConfig: const WireGuardConfig(
          rawConfig: '[Interface]\nPrivateKey = aaa\nAddress = 10.0.0.2\n[Peer]\nPublicKey = bbb\nEndpoint = 1.2.3.4:51820',
          privateKey: 'aaa',
          peerPublicKey: 'bbb',
          address: '10.0.0.2',
          endpoint: '1.2.3.4:51820',
        ),
        udp2rawConfig: const Udp2RawConfig(
          serverIp: '1.2.3.4',
          remotePort: 4097,
          localPort: 1234,
          password: 'secret_password_123',
        ),
      );

      final exported = original.exportJson();
      final restored = VpnProfile.fromJson(jsonDecode(exported));

      expect(restored.name, original.name);
      expect(restored.tunnelMode, TunnelMode.udp2raw);
      expect(restored.udp2rawConfig.password, 'secret_password_123');
      expect(restored.wireGuardConfig.endpoint, '1.2.3.4:51820');
    });
  });
}
