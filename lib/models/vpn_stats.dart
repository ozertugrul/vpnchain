enum VpnStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  disconnecting,
  error;

  String get displayName {
    switch (this) {
      case VpnStatus.disconnected:
        return 'Disconnected';
      case VpnStatus.connecting:
        return 'Connecting...';
      case VpnStatus.connected:
        return 'Protected';
      case VpnStatus.reconnecting:
        return 'Reconnecting...';
      case VpnStatus.disconnecting:
        return 'Disconnecting...';
      case VpnStatus.error:
        return 'Error';
    }
  }

  bool get isActive => this == VpnStatus.connected;
  bool get isTransitioning =>
      this == VpnStatus.connecting ||
      this == VpnStatus.disconnecting ||
      this == VpnStatus.reconnecting;
}

enum HandshakeStatus {
  standby,
  initiating,
  confirmed,
  timedOut;

  String get displayName {
    switch (this) {
      case HandshakeStatus.standby:
        return 'Standby';
      case HandshakeStatus.initiating:
        return 'Initiating Handshake...';
      case HandshakeStatus.confirmed:
        return 'Handshake Confirmed (Active)';
      case HandshakeStatus.timedOut:
        return 'Handshake Timeout (Retrying)';
    }
  }
}

class VpnStats {
  final VpnStatus status;
  final int uploadSpeed; // B/s
  final int downloadSpeed; // B/s
  final int totalUpload; // bytes
  final int totalDownload; // bytes
  final int txPackets; // count
  final int rxPackets; // count
  final int fecParityPackets; // count
  final int pingMs; // milliseconds
  final int uptimeSeconds; // seconds
  final HandshakeStatus handshakeStatus;
  final DateTime? lastHandshake;
  final List<double> speedHistoryDown;
  final List<double> speedHistoryUp;
  final String? errorMessage;

  const VpnStats({
    this.status = VpnStatus.disconnected,
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.totalUpload = 0,
    this.totalDownload = 0,
    this.txPackets = 0,
    this.rxPackets = 0,
    this.fecParityPackets = 0,
    this.pingMs = 0,
    this.uptimeSeconds = 0,
    this.handshakeStatus = HandshakeStatus.standby,
    this.lastHandshake,
    this.speedHistoryDown = const [],
    this.speedHistoryUp = const [],
    this.errorMessage,
  });

  VpnStats copyWith({
    VpnStatus? status,
    int? uploadSpeed,
    int? downloadSpeed,
    int? totalUpload,
    int? totalDownload,
    int? txPackets,
    int? rxPackets,
    int? fecParityPackets,
    int? pingMs,
    int? uptimeSeconds,
    HandshakeStatus? handshakeStatus,
    DateTime? lastHandshake,
    List<double>? speedHistoryDown,
    List<double>? speedHistoryUp,
    String? errorMessage,
  }) {
    return VpnStats(
      status: status ?? this.status,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      totalUpload: totalUpload ?? this.totalUpload,
      totalDownload: totalDownload ?? this.totalDownload,
      txPackets: txPackets ?? this.txPackets,
      rxPackets: rxPackets ?? this.rxPackets,
      fecParityPackets: fecParityPackets ?? this.fecParityPackets,
      pingMs: pingMs ?? this.pingMs,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      handshakeStatus: handshakeStatus ?? this.handshakeStatus,
      lastHandshake: lastHandshake ?? this.lastHandshake,
      speedHistoryDown: speedHistoryDown ?? this.speedHistoryDown,
      speedHistoryUp: speedHistoryUp ?? this.speedHistoryUp,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
