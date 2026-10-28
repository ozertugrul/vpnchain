import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'tunnel_mode.dart';
import 'wireguard_config.dart';
import 'udpspeeder_config.dart';
import 'udp2raw_config.dart';

class VpnProfile {
  final String id;
  final String name;
  final TunnelMode tunnelMode;
  final WireGuardConfig wireGuardConfig;
  final UdpSpeederConfig udpSpeederConfig;
  final Udp2RawConfig udp2rawConfig;
  final DateTime createdAt;
  final DateTime? lastConnectedAt;

  VpnProfile({
    String? id,
    required this.name,
    this.tunnelMode = TunnelMode.udpspeeder,
    required this.wireGuardConfig,
    UdpSpeederConfig? udpSpeederConfig,
    Udp2RawConfig? udp2rawConfig,
    DateTime? createdAt,
    this.lastConnectedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        udpSpeederConfig = udpSpeederConfig ?? const UdpSpeederConfig(),
        udp2rawConfig = udp2rawConfig ?? const Udp2RawConfig();

  /// Gets the active server address (IP or hostname) based on the selected mode.
  String get activeServerIp {
    switch (tunnelMode) {
      case TunnelMode.udpspeeder:
        return udpSpeederConfig.serverIp.isNotEmpty
            ? udpSpeederConfig.serverIp
            : wireGuardConfig.serverHost;
      case TunnelMode.udp2raw:
        return udp2rawConfig.serverIp.isNotEmpty
            ? udp2rawConfig.serverIp
            : wireGuardConfig.serverHost;
      case TunnelMode.direct:
        return wireGuardConfig.serverHost;
    }
  }

  /// Gets the active target port based on mode.
  int get activeTargetPort {
    switch (tunnelMode) {
      case TunnelMode.udpspeeder:
        return udpSpeederConfig.remotePort;
      case TunnelMode.udp2raw:
        return udp2rawConfig.remotePort;
      case TunnelMode.direct:
        return wireGuardConfig.serverPort ?? 51820;
    }
  }

  /// Gets the active local listen port based on mode.
  int get activeLocalPort {
    switch (tunnelMode) {
      case TunnelMode.udpspeeder:
        return udpSpeederConfig.localPort;
      case TunnelMode.udp2raw:
        return udp2rawConfig.localPort;
      case TunnelMode.direct:
        return 0; // Not applicable for direct mode
    }
  }

  VpnProfile copyWith({
    String? id,
    String? name,
    TunnelMode? tunnelMode,
    WireGuardConfig? wireGuardConfig,
    UdpSpeederConfig? udpSpeederConfig,
    Udp2RawConfig? udp2rawConfig,
    DateTime? createdAt,
    DateTime? lastConnectedAt,
  }) {
    return VpnProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      tunnelMode: tunnelMode ?? this.tunnelMode,
      wireGuardConfig: wireGuardConfig ?? this.wireGuardConfig,
      udpSpeederConfig: udpSpeederConfig ?? this.udpSpeederConfig,
      udp2rawConfig: udp2rawConfig ?? this.udp2rawConfig,
      createdAt: createdAt ?? this.createdAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tunnelMode': tunnelMode.name,
        'wireGuardConfig': wireGuardConfig.toJson(),
        'udpSpeederConfig': udpSpeederConfig.toJson(),
        'udp2rawConfig': udp2rawConfig.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'lastConnectedAt': lastConnectedAt?.toIso8601String(),
      };

  factory VpnProfile.fromJson(Map<String, dynamic> json) {
    // 1. WireGuard Config parsing (supports both rawConfig & legacy rawConfigText)
    WireGuardConfig wg;
    if (json['wireGuardConfig'] is Map<String, dynamic>) {
      final wgMap = json['wireGuardConfig'] as Map<String, dynamic>;
      final raw = (wgMap['rawConfig'] ?? wgMap['rawConfigText']) as String? ?? '';
      wg = WireGuardConfig.parse(raw);
    } else {
      wg = const WireGuardConfig(rawConfig: '');
    }

    // 2. UDPspeeder Config parsing (supports legacy .selconf schema)
    UdpSpeederConfig speeder = const UdpSpeederConfig();
    if (json['udpSpeederConfig'] is Map<String, dynamic>) {
      final spMap = json['udpSpeederConfig'] as Map<String, dynamic>;
      final sIp = spMap['serverIp'] as String? ?? '';
      final rPort = int.tryParse(spMap['remotePort']?.toString() ?? '') ?? 4096;
      final lPort = int.tryParse(spMap['localPort']?.toString() ?? '') ?? 1234;
      final presetStr = spMap['preset']?.toString().toUpperCase() ?? '';

      UdpSpeederPreset p = UdpSpeederPreset.normal;
      if (presetStr == 'FEC' || presetStr == 'FEC1_2') {
        p = UdpSpeederPreset.fec1_2;
      } else if (presetStr == 'FEC1_5') {
        p = UdpSpeederPreset.fec1_5;
      } else if (presetStr == 'FEC2_2') {
        p = UdpSpeederPreset.fec2_2;
      }

      speeder = UdpSpeederConfig(
        serverIp: sIp,
        remotePort: rPort,
        localPort: lPort,
        password: spMap['password'] as String? ?? 'vpnchain_secret',
        preset: p,
      );
    }

    // 3. udp2raw Config parsing
    Udp2RawConfig rawCfg = const Udp2RawConfig();
    if (json['udp2rawConfig'] is Map<String, dynamic>) {
      rawCfg = Udp2RawConfig.fromJson(json['udp2rawConfig'] as Map<String, dynamic>);
    }

    // 4. Mode
    TunnelMode mode = TunnelMode.udpspeeder;
    if (json['tunnelMode'] != null) {
      mode = TunnelMode.fromString(json['tunnelMode'].toString());
    }

    return VpnProfile(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'VPN Profile',
      tunnelMode: mode,
      wireGuardConfig: wg,
      udpSpeederConfig: speeder,
      udp2rawConfig: rawCfg,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.tryParse(json['lastConnectedAt'] as String)
          : null,
    );
  }

  /// Exports this profile to formatted JSON string.
  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}
