enum TunnelMode {
  udpspeeder,
  udp2raw,
  direct;

  String get displayName {
    switch (this) {
      case TunnelMode.udpspeeder:
        return 'UDPspeeder';
      case TunnelMode.udp2raw:
        return 'udp2raw (FakeTCP)';
      case TunnelMode.direct:
        return 'Direct WireGuard';
    }
  }

  String get description {
    switch (this) {
      case TunnelMode.udpspeeder:
        return 'Forward Error Correction (FEC) & packet obfuscation to bypass packet drops and throttling.';
      case TunnelMode.udp2raw:
        return 'Disguises UDP packets as simulated TCP/ICMP connections to bypass strict DPI and UDP firewalls.';
      case TunnelMode.direct:
        return 'Standard direct WireGuard connection without packet obfuscation.';
    }
  }

  String get tag {
    switch (this) {
      case TunnelMode.udpspeeder:
        return 'udpspeeder';
      case TunnelMode.udp2raw:
        return 'udp2raw';
      case TunnelMode.direct:
        return 'direct';
    }
  }

  static TunnelMode fromString(String? val) {
    if (val == null) return TunnelMode.udpspeeder;
    for (final mode in TunnelMode.values) {
      if (mode.name.toLowerCase() == val.toLowerCase() ||
          mode.tag.toLowerCase() == val.toLowerCase()) {
        return mode;
      }
    }
    return TunnelMode.udpspeeder;
  }
}
