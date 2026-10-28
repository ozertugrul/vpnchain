enum UdpSpeederPreset {
  normal,
  fec1_5,
  fec1_2,
  fec2_2;

  String get displayName {
    switch (this) {
      case UdpSpeederPreset.normal:
        return 'Normal (Low Latency, No Parity)';
      case UdpSpeederPreset.fec1_5:
        return 'Light FEC (f1:5, +20% Redundancy)';
      case UdpSpeederPreset.fec1_2:
        return 'Medium FEC (f1:2, +50% Redundancy - Recommended)';
      case UdpSpeederPreset.fec2_2:
        return 'Aggressive FEC (f2:2, +100% Extreme Reliability)';
    }
  }

  String get fecArg {
    switch (this) {
      case UdpSpeederPreset.normal:
        return '';
      case UdpSpeederPreset.fec1_5:
        return '-f1:5';
      case UdpSpeederPreset.fec1_2:
        return '-f1:2';
      case UdpSpeederPreset.fec2_2:
        return '-f2:2';
    }
  }
}

class UdpSpeederConfig {
  final String serverIp;
  final int remotePort;
  final int localPort;
  final String password;
  final UdpSpeederPreset preset;
  final int mode; // 1 = low latency, 0 = standard
  final int timeout; // seconds
  final int mtu;
  final String extraArgs;

  const UdpSpeederConfig({
    this.serverIp = '',
    this.remotePort = 4096,
    this.localPort = 1234,
    this.password = 'vpnchain_secret',
    this.preset = UdpSpeederPreset.normal,
    this.mode = 1,
    this.timeout = 5,
    this.mtu = 1280,
    this.extraArgs = '',
  });

  /// Builds the CLI argument string used by the native binary.
  String buildCliParams() {
    final List<String> args = [
      '-c',
      '-l', '127.0.0.1:$localPort',
      '-r', '$serverIp:$remotePort',
    ];

    if (password.isNotEmpty) {
      args.addAll(['-k', password]);
    }

    if (preset.fecArg.isNotEmpty) {
      args.add(preset.fecArg);
    }

    args.addAll([
      '--mode', mode.toString(),
      '--timeout', timeout.toString(),
      '--mtu', mtu.toString(),
    ]);

    if (extraArgs.trim().isNotEmpty) {
      args.addAll(extraArgs.trim().split(RegExp(r'\s+')));
    }

    return args.join(' ');
  }

  UdpSpeederConfig copyWith({
    String? serverIp,
    int? remotePort,
    int? localPort,
    String? password,
    UdpSpeederPreset? preset,
    int? mode,
    int? timeout,
    int? mtu,
    String? extraArgs,
  }) {
    return UdpSpeederConfig(
      serverIp: serverIp ?? this.serverIp,
      remotePort: remotePort ?? this.remotePort,
      localPort: localPort ?? this.localPort,
      password: password ?? this.password,
      preset: preset ?? this.preset,
      mode: mode ?? this.mode,
      timeout: timeout ?? this.timeout,
      mtu: mtu ?? this.mtu,
      extraArgs: extraArgs ?? this.extraArgs,
    );
  }

  Map<String, dynamic> toJson() => {
        'serverIp': serverIp,
        'remotePort': remotePort,
        'localPort': localPort,
        'password': password,
        'preset': preset.name,
        'mode': mode,
        'timeout': timeout,
        'mtu': mtu,
        'extraArgs': extraArgs,
      };

  factory UdpSpeederConfig.fromJson(Map<String, dynamic> json) {
    UdpSpeederPreset p = UdpSpeederPreset.normal;
    final presetStr = json['preset'] as String?;
    if (presetStr != null) {
      p = UdpSpeederPreset.values.firstWhere(
        (e) => e.name.toLowerCase() == presetStr.toLowerCase(),
        orElse: () => UdpSpeederPreset.normal,
      );
    }

    return UdpSpeederConfig(
      serverIp: json['serverIp'] as String? ?? '',
      remotePort: json['remotePort'] as int? ?? 4096,
      localPort: json['localPort'] as int? ?? 1234,
      password: json['password'] as String? ?? 'vpnchain_secret',
      preset: p,
      mode: json['mode'] as int? ?? 1,
      timeout: json['timeout'] as int? ?? 5,
      mtu: json['mtu'] as int? ?? 1280,
      extraArgs: json['extraArgs'] as String? ?? '',
    );
  }
}
