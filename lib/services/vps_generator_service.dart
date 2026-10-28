import '../models/vpn_profile.dart';

class VpsGeneratorService {
  /// Generates a ready-to-run docker-compose.yml for the user's VPS.
  static String generateDockerCompose(VpnProfile profile) {
    final speederPort = profile.udpSpeederConfig.remotePort;
    final speederSecret = profile.udpSpeederConfig.password;
    final speederFec = profile.udpSpeederConfig.preset.fecArg.isNotEmpty
        ? profile.udpSpeederConfig.preset.fecArg
        : '-f1:2';

    final udp2rawPort = profile.udp2rawConfig.remotePort;
    final udp2rawSecret = profile.udp2rawConfig.password;

    return '''
# =======================================================
# VPNChain VPS Server Stack (Docker Compose)
# Runs WireGuard + UDPspeeder + udp2raw concurrently
# =======================================================
version: '3.8'

services:
  # 1. WireGuard VPN Server (Listening locally on internal port 51820)
  wireguard:
    image: lscr.io/linuxserver/wireguard:latest
    container_name: vpnchain_wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=UTC
      - SERVERURL=${profile.activeServerIp.isNotEmpty ? profile.activeServerIp : "YOUR_VPS_IP"}
      - SERVERPORT=51820
      - PEERS=1
      - PEERDNS=1.1.1.1
      - INTERNAL_SUBNET=10.13.13.0
      - ALLOWEDIPS=0.0.0.0/0
    volumes:
      - ./wireguard-config:/config
      - /lib/modules:/lib/modules
    network_mode: host
    restart: unless-stopped

  # 2. UDPspeeder Server (FEC & Obfuscation Layer)
  # Public Port: $speederPort -> Local WireGuard: 127.0.0.1:51820
  udpspeeder:
    image: wangyu-/speederv2:latest
    container_name: vpnchain_udpspeeder
    command: >
      -s -l 0.0.0.0:$speederPort -r 127.0.0.1:51820
      -k "$speederSecret"
      $speederFec --mode 1 --timeout 5 --mtu 1280
    network_mode: host
    restart: unless-stopped

  # 3. udp2raw Server (FakeTCP DPI Bypass Layer)
  # Public Port: $udp2rawPort -> Local WireGuard: 127.0.0.1:51820
  udp2raw:
    image: wangyu-/udp2raw:latest
    container_name: vpnchain_udp2raw
    cap_add:
      - NET_ADMIN
    command: >
      -s -l 0.0.0.0:$udp2rawPort -r 127.0.0.1:51820
      -k "$udp2rawSecret"
      --raw-mode faketcp --cipher-mode aes128cbc --auth-mode simple --seq-mode 3 --fix-gro
    network_mode: host
    restart: unless-stopped
''';
  }

  /// Generates a turnkey Bash setup script for Ubuntu / Debian VPS.
  static String generateBashScript(VpnProfile profile) {
    final speederPort = profile.udpSpeederConfig.remotePort;
    final speederSecret = profile.udpSpeederConfig.password;
    final speederFec = profile.udpSpeederConfig.preset.fecArg.isNotEmpty
        ? profile.udpSpeederConfig.preset.fecArg
        : '-f1:2';

    final udp2rawPort = profile.udp2rawConfig.remotePort;
    final udp2rawSecret = profile.udp2rawConfig.password;

    return '''
#!/bin/bash
# =======================================================
# VPNChain Quick Server Setup Script (Ubuntu / Debian)
# =======================================================
set -e

echo "=== [1/4] Updating packages and installing dependencies ==="
sudo apt-get update
sudo apt-get install -y wireguard iptables curl wget tar net-tools

echo "=== [2/4] Downloading UDPspeeder & udp2raw binaries ==="
mkdir -p /opt/vpnchain
cd /opt/vpnchain

# Download UDPspeeder
wget -qO speederv2.tar.gz https://github.com/wangyu-/UDPspeeder/releases/latest/download/speederv2_binaries.tar.gz || true
if [ -f speederv2.tar.gz ]; then
  tar -zxf speederv2.tar.gz
  chmod +x speederv2_amd64
  mv speederv2_amd64 /usr/local/bin/speederv2
fi

# Download udp2raw
wget -qO udp2raw.tar.gz https://github.com/wangyu-/udp2raw-tunnel/releases/latest/download/udp2raw_binaries.tar.gz || true
if [ -f udp2raw.tar.gz ]; then
  tar -zxf udp2raw.tar.gz
  chmod +x udp2raw_amd64
  mv udp2raw_amd64 /usr/local/bin/udp2raw
fi

echo "=== [3/4] Enabling IP Forwarding & Firewall ==="
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Allow ports in UFW / iptables
ufw allow $speederPort/udp || true
ufw allow $udp2rawPort/tcp || true

echo "=== [4/4] Starting Server Services ==="
# UDPspeeder Server daemon
nohup /usr/local/bin/speederv2 -s -l 0.0.0.0:$speederPort -r 127.0.0.1:51820 -k "$speederSecret" $speederFec --mode 1 --timeout 5 --mtu 1280 > /var/log/udpspeeder.log 2>&1 &

# udp2raw Server daemon (FakeTCP)
nohup /usr/local/bin/udp2raw -s -l 0.0.0.0:$udp2rawPort -r 127.0.0.1:51820 -k "$udp2rawSecret" --raw-mode faketcp --cipher-mode aes128cbc --seq-mode 3 --fix-gro > /var/log/udp2raw.log 2>&1 &

echo "=========================================================="
echo " VPNChain Server Setup Complete! 🚀"
echo " WireGuard is bound locally on 127.0.0.1:51820"
echo " UDPspeeder listening on 0.0.0.0:$speederPort (UDP)"
echo " udp2raw listening on 0.0.0.0:$udp2rawPort (FakeTCP)"
echo "=========================================================="
''';
  }
}
