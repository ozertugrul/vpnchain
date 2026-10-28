class WireGuardConfig {
  final String rawConfig;
  final String privateKey;
  final String address;
  final String dns;
  final int mtu;
  final String peerPublicKey;
  final String? presharedKey;
  final String endpoint;
  final String allowedIps;
  final int? persistentKeepalive;

  const WireGuardConfig({
    required this.rawConfig,
    this.privateKey = '',
    this.address = '',
    this.dns = '1.1.1.1, 8.8.8.8',
    this.mtu = 1280,
    this.peerPublicKey = '',
    this.presharedKey,
    this.endpoint = '',
    this.allowedIps = '0.0.0.0/0, ::/0',
    this.persistentKeepalive = 25,
  });

  /// Extracts the IP or hostname portion of the endpoint.
  String get serverHost {
    if (endpoint.isEmpty) return '';
    final lastColon = endpoint.lastIndexOf(':');
    if (lastColon != -1) {
      final host = endpoint.substring(0, lastColon).trim();
      // Remove IPv6 brackets if present, e.g. [2001:db8::1] -> 2001:db8::1
      if (host.startsWith('[') && host.endsWith(']')) {
        return host.substring(1, host.length - 1);
      }
      return host;
    }
    return endpoint.trim();
  }

  /// Extracts the port portion of the endpoint.
  int? get serverPort {
    if (endpoint.isEmpty) return null;
    final lastColon = endpoint.lastIndexOf(':');
    if (lastColon != -1 && lastColon + 1 < endpoint.length) {
      return int.tryParse(endpoint.substring(lastColon + 1).trim());
    }
    return null;
  }

  /// Checks if the basic mandatory WireGuard parameters are populated.
  bool get isValid {
    return privateKey.trim().isNotEmpty &&
        peerPublicKey.trim().isNotEmpty &&
        address.trim().isNotEmpty;
  }

  /// Generates the chained configuration where the Endpoint points to
  /// the local obfuscation tunnel (`127.0.0.1:<localPort>`), and MTU is adjusted.
  String generateChainedConfig({required int localPort, int targetMtu = 1280}) {
    final buffer = StringBuffer();
    buffer.writeln('[Interface]');
    if (privateKey.isNotEmpty) buffer.writeln('PrivateKey = $privateKey');
    if (address.isNotEmpty) buffer.writeln('Address = $address');
    if (dns.isNotEmpty) buffer.writeln('DNS = $dns');
    buffer.writeln('MTU = $targetMtu');
    buffer.writeln();

    buffer.writeln('[Peer]');
    if (peerPublicKey.isNotEmpty) buffer.writeln('PublicKey = $peerPublicKey');
    if (presharedKey != null && presharedKey!.trim().isNotEmpty) {
      buffer.writeln('PresharedKey = ${presharedKey!.trim()}');
    }
    buffer.writeln('Endpoint = 127.0.0.1:$localPort');
    buffer.writeln('AllowedIPs = ${allowedIps.isEmpty ? "0.0.0.0/0, ::/0" : allowedIps}');
    if (persistentKeepalive != null && persistentKeepalive! > 0) {
      buffer.writeln('PersistentKeepalive = $persistentKeepalive');
    }

    return buffer.toString();
  }

  /// Parses an INI-style WireGuard .conf file.
  factory WireGuardConfig.parse(String raw) {
    String privKey = '';
    String addr = '';
    String dnsServers = '1.1.1.1, 8.8.8.8';
    int parsedMtu = 1280;
    String pubKey = '';
    String? psk;
    String ep = '';
    String allowed = '0.0.0.0/0, ::/0';
    int? keepalive = 25;

    String currentSection = '';
    final lines = raw.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) {
        continue;
      }

      if (line.startsWith('[') && line.endsWith(']')) {
        currentSection = line.substring(1, line.length - 1).trim().toLowerCase();
        continue;
      }

      final eqIdx = line.indexOf('=');
      if (eqIdx == -1) continue;

      final key = line.substring(0, eqIdx).trim().toLowerCase();
      final value = line.substring(eqIdx + 1).trim();

      if (currentSection == 'interface') {
        switch (key) {
          case 'privatekey':
            privKey = value;
            break;
          case 'address':
            addr = value;
            break;
          case 'dns':
            dnsServers = value;
            break;
          case 'mtu':
            parsedMtu = int.tryParse(value) ?? 1280;
            break;
        }
      } else if (currentSection == 'peer') {
        switch (key) {
          case 'publickey':
            pubKey = value;
            break;
          case 'presharedkey':
            psk = value;
            break;
          case 'endpoint':
            ep = value;
            break;
          case 'allowedips':
            allowed = value;
            break;
          case 'persistentkeepalive':
            keepalive = int.tryParse(value);
            break;
        }
      }
    }

    return WireGuardConfig(
      rawConfig: raw,
      privateKey: privKey,
      address: addr,
      dns: dnsServers,
      mtu: parsedMtu,
      peerPublicKey: pubKey,
      presharedKey: psk,
      endpoint: ep,
      allowedIps: allowed,
      persistentKeepalive: keepalive,
    );
  }

  Map<String, dynamic> toJson() => {
        'rawConfig': rawConfig,
        'privateKey': privateKey,
        'address': address,
        'dns': dns,
        'mtu': mtu,
        'peerPublicKey': peerPublicKey,
        'presharedKey': presharedKey,
        'endpoint': endpoint,
        'allowedIps': allowedIps,
        'persistentKeepalive': persistentKeepalive,
      };

  factory WireGuardConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['rawConfig'] as String? ?? '';
    if (raw.isNotEmpty && (json['privateKey'] == null || json['privateKey'] == '')) {
      return WireGuardConfig.parse(raw);
    }
    return WireGuardConfig(
      rawConfig: raw,
      privateKey: json['privateKey'] as String? ?? '',
      address: json['address'] as String? ?? '',
      dns: json['dns'] as String? ?? '1.1.1.1, 8.8.8.8',
      mtu: json['mtu'] as int? ?? 1280,
      peerPublicKey: json['peerPublicKey'] as String? ?? '',
      presharedKey: json['presharedKey'] as String?,
      endpoint: json['endpoint'] as String? ?? '',
      allowedIps: json['allowedIps'] as String? ?? '0.0.0.0/0, ::/0',
      persistentKeepalive: json['persistentKeepalive'] as int? ?? 25,
    );
  }
}
