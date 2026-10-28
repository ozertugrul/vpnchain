enum RawMode {
  faketcp,
  udp,
  icmp;

  String get displayName {
    switch (this) {
      case RawMode.faketcp:
        return 'FakeTCP (Simulates TCP Handshake - Best for Strict DPI)';
      case RawMode.udp:
        return 'UDP Obfuscation (Masks UDP Header & Payload)';
      case RawMode.icmp:
        return 'ICMP Echo (Tunnels via ICMP Ping Packets)';
    }
  }

  String get cliValue => name;
}

enum CipherMode {
  aes128cbc,
  xor,
  none;

  String get displayName {
    switch (this) {
      case CipherMode.aes128cbc:
        return 'AES-128-CBC (Strong Encryption)';
      case CipherMode.xor:
        return 'XOR (Lightweight & Fast Obfuscation)';
      case CipherMode.none:
        return 'None (Zero Overhead)';
    }
  }

  String get cliValue {
    switch (this) {
      case CipherMode.aes128cbc:
        return 'aes128cbc';
      case CipherMode.xor:
        return 'xor';
      case CipherMode.none:
        return 'none';
    }
  }
}

enum AuthMode {
  simple,
  md5,
  crc32,
  none;

  String get cliValue => name;
}

class Udp2RawConfig {
  final String serverIp;
  final int remotePort;
  final int localPort;
  final String password;
  final RawMode rawMode;
  final CipherMode cipherMode;
  final AuthMode authMode;
  final int seqMode;
  final bool fixGro;
  final String extraArgs;

  const Udp2RawConfig({
    this.serverIp = '',
    this.remotePort = 4097,
    this.localPort = 1234,
    this.password = 'vpnchain_secret',
    this.rawMode = RawMode.faketcp,
    this.cipherMode = CipherMode.aes128cbc,
    this.authMode = AuthMode.simple,
    this.seqMode = 3,
    this.fixGro = true,
    this.extraArgs = '',
  });

  /// Builds the CLI argument string for udp2raw binary execution.
  String buildCliParams() {
    final List<String> args = [
      '-c',
      '-l', '127.0.0.1:$localPort',
      '-r', '$serverIp:$remotePort',
    ];

    if (password.isNotEmpty) {
      args.addAll(['-k', password]);
    }

    args.addAll([
      '--raw-mode', rawMode.cliValue,
      '--cipher-mode', cipherMode.cliValue,
      '--auth-mode', authMode.cliValue,
      '--seq-mode', seqMode.toString(),
    ]);

    if (fixGro) {
      args.add('--fix-gro');
    }

    if (extraArgs.trim().isNotEmpty) {
      args.addAll(extraArgs.trim().split(RegExp(r'\s+')));
    }

    return args.join(' ');
  }

  Udp2RawConfig copyWith({
    String? serverIp,
    int? remotePort,
    int? localPort,
    String? password,
    RawMode? rawMode,
    CipherMode? cipherMode,
    AuthMode? authMode,
    int? seqMode,
    bool? fixGro,
    String? extraArgs,
  }) {
    return Udp2RawConfig(
      serverIp: serverIp ?? this.serverIp,
      remotePort: remotePort ?? this.remotePort,
      localPort: localPort ?? this.localPort,
      password: password ?? this.password,
      rawMode: rawMode ?? this.rawMode,
      cipherMode: cipherMode ?? this.cipherMode,
      authMode: authMode ?? this.authMode,
      seqMode: seqMode ?? this.seqMode,
      fixGro: fixGro ?? this.fixGro,
      extraArgs: extraArgs ?? this.extraArgs,
    );
  }

  Map<String, dynamic> toJson() => {
        'serverIp': serverIp,
        'remotePort': remotePort,
        'localPort': localPort,
        'password': password,
        'rawMode': rawMode.name,
        'cipherMode': cipherMode.name,
        'authMode': authMode.name,
        'seqMode': seqMode,
        'fixGro': fixGro,
        'extraArgs': extraArgs,
      };

  factory Udp2RawConfig.fromJson(Map<String, dynamic> json) {
    RawMode rMode = RawMode.faketcp;
    final rStr = json['rawMode'] as String?;
    if (rStr != null) {
      rMode = RawMode.values.firstWhere(
        (e) => e.name.toLowerCase() == rStr.toLowerCase(),
        orElse: () => RawMode.faketcp,
      );
    }

    CipherMode cMode = CipherMode.aes128cbc;
    final cStr = json['cipherMode'] as String?;
    if (cStr != null) {
      cMode = CipherMode.values.firstWhere(
        (e) => e.name.toLowerCase() == cStr.toLowerCase(),
        orElse: () => CipherMode.aes128cbc,
      );
    }

    AuthMode aMode = AuthMode.simple;
    final aStr = json['authMode'] as String?;
    if (aStr != null) {
      aMode = AuthMode.values.firstWhere(
        (e) => e.name.toLowerCase() == aStr.toLowerCase(),
        orElse: () => AuthMode.simple,
      );
    }

    return Udp2RawConfig(
      serverIp: json['serverIp'] as String? ?? '',
      remotePort: json['remotePort'] as int? ?? 4097,
      localPort: json['localPort'] as int? ?? 1234,
      password: json['password'] as String? ?? 'vpnchain_secret',
      rawMode: rMode,
      cipherMode: cMode,
      authMode: aMode,
      seqMode: json['seqMode'] as int? ?? 3,
      fixGro: json['fixGro'] as bool? ?? true,
      extraArgs: json['extraArgs'] as String? ?? '',
    );
  }
}
