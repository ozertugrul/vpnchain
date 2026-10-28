# VPNChain 🚀 (Flutter Multi-Platform Edition)

<div align="center">
  <img src="assets/images/logo.png" width="130" alt="VPNChain Logo" />

  ### Multi-Platform WireGuard Tunneling with UDPspeeder & udp2raw Obfuscation
  **Bypass ISP DPI Signature Detection • Eliminate Packet Drops • Simulated FakeTCP**

  [![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue.svg)](https://apple.com/macos)
  [![iOS](https://img.shields.io/badge/iOS-15.0%2B-purple.svg)](https://apple.com/ios)
  [![Windows](https://img.shields.io/badge/Windows-7%20--%2011-0078D6.svg)](https://microsoft.com/windows)
  [![Android](https://img.shields.io/badge/Android-5.0%2B%20(API%2021%2B)-green.svg)](https://android.com)
  [![Flutter](https://img.shields.io/badge/Flutter-3.44%2B-02569B.svg)](https://flutter.dev)
  [![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)
</div>

---

*🇹🇷 [Türkçe Dokümantasyon](#-türkçe-dokümantasyon) | 🇬🇧 [English Documentation](#-english-documentation)*

---

# 🇹🇷 Türkçe Dokümantasyon

## 🎯 Projenin Amacı ve Çözülen Problem

Birçok internet servis sağlayıcısı (İSS / ISP), internet sansürü ve kısıtlamaları kapsamında **Derin Paket İncelemesi (DPI - Deep Packet Inspection)** sistemleri kullanır. 

Standard bir WireGuard VPN bağlantısında paketler doğrudan UDP üzerinden gönderilir:
- El sıkışma başlatma paketleri (`Type 0x01`, 148 bayt)
- El sıkışma yanıt paketleri (`Type 0x02`, 92 bayt)
- Taşıma verisi paketleri (`Type 0x04`)

İSS DPI donanımları bu sabit imza ve başlık baytlarını saniyeler içinde tespit ederek **WireGuard paketlerini tamamen düşürür (drop)** veya bağlantıyı tıkar (UDP QoS throttling). Bu durumda standart WireGuard istemcileri el sıkışmasını tamamlayamaz veya birkaç saniye sonra kopar.

**VPNChain**, bu sorunu çözmek için WireGuard'ı yerel bir tünelleme katmanıyla zincirler (chain). WireGuard trafiği doğrudan sunucuya değil, yerel `127.0.0.1:<local_port>` portuna yönlendirilir. Uygulama içerisindeki gizleme motoru paketleri alarak başlıkları dönüştürür, WireGuard imzalarını tamamen siler ve sunucuya güvenli şekilde iletir.

---

## ⚡ Desteklenen 2 Çalışma Modu

### 1. 🚀 UDPspeeder Modu (FEC & Paket Kurtarma)
* **Ne Yapar?** WireGuard UDP paketlerini UDPspeeder protokolüyle sarmalar, her pakete rastgele salt ekleyerek şifreler (XOR/AES) ve İleri Hata Düzeltme (**Forward Error Correction - FEC**) uygular.
* **Ne Zaman Kullanılır?** İSS'nin UDP paketlerini düşürdüğü, dalgalı mobil (4G/5G) veya yüksek paket kayıplı Wi-Fi ağlarında.
* **Avantajı:** Örneğin `1:2` FEC modunda her 2 pakette 1 yedek kurtarma paketi üretilir. İSS bir paketi düşürse bile veri paket kaybı yaşamadan karşı tarafta anında matematiksel olarak kurtarılır!

### 2. 🛡️ udp2raw Modu (FakeTCP & DPI Aldatma)
* **Ne Yapar?** WireGuard UDP paketlerini sahte bir **TCP (FakeTCP)** bağlantısı içine hapseder. Gerçek bir TCP 3'lü el sıkışması (`SYN` -> `SYN/ACK` -> `ACK`), TCP sıra (seq/ack) numaraları ve TCP başlıkları üretir.
* **Ne Zaman Kullanılır?** İSS'nin tüm UDP trafiğini engellediği, UDP portlarını kısıtladığı veya çok agresif DPI filtreleri uyguladığı durumlarda.
* **Avantajı:** İSS DPI ve güvenlik duvarları trafiği normal bir web/TCP trafiği olarak görür; WireGuard UDP imzası tamamen yok olur!

---

## 📱 Platform Desteği

| Platform | Asgari Desteklenen Sürüm | Mimari |
|---|---|---|
| **macOS** | macOS 12.0 / 15.0+ (Sequoia uyumlu) | Apple Silicon (M1/M2/M3/M4) & Intel |
| **iOS** | iOS 15.0+ | arm64 |
| **Windows** | Windows 7, 8.1, 10, 11 | x86_64 / x86 |
| **Android** | Android 5.0+ (API 21+) ile Android 15/16 arası | arm64-v8a, armeabi-v7a, x86_64 |

---

## 🏗️ Mimari & Çalışma Mantığı

```
[Kullanıcı Trafiği]
       │
       ▼
[Sistem TUN Arayüzü (WireGuard Client)]
       │
       ▼  (UDP Hedef: 127.0.0.1:1234, MTU: 1280)
[VPNChain Gizleme Motoru (UDPspeeder / udp2raw)]
       │
       │  (WireGuard İmzaları Silinmiş, Sahte TCP / FEC Sarmallı Paketler)
       ▼
[İnternet / İSS DPI Filtresi] ────► (DPI Tarafından Görünmez, Engellenemez)
       │
       ▼
[VPS Sunucusu: UDPspeeder / udp2raw Dinleyicisi]
       │  (Paket Açılır, Orijinal WireGuard Paketine Dönüştürülür)
       ▼
[VPS: WireGuard Server (127.0.0.1:51820)]
       │
       ▼
[Özgür İnternet 🌐]
```

---

## 🖥️ VPS Sunucu Kurulumu

Uygulamanın içindeki **"Server Deployment" (VPS Kurulum)** ekranından tek tıkla Docker Compose dosyasını veya Bash kurulum betiğini kopyalayabilirsiniz.

### Docker Compose ile Hızlı Başlatma (`docker-compose.yml`):
```yaml
version: '3.8'

services:
  # 1. WireGuard VPN Sunucusu (Yerel 51820 portunda dinler)
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
      - SERVERURL=YOUR_VPS_IP
      - SERVERPORT=51820
      - PEERS=1
      - PEERDNS=1.1.1.1
      - INTERNAL_SUBNET=10.13.13.0
      - ALLOWEDIPS=0.0.0.0/0
    volumes:
      - ./wireguard-config:/config
    network_mode: host
    restart: unless-stopped

  # 2. UDPspeeder Sunucusu (Dış Port: 4096 UDP -> İç WireGuard: 127.0.0.1:51820)
  udpspeeder:
    image: wangyu-/speederv2:latest
    container_name: vpnchain_udpspeeder
    command: -s -l 0.0.0.0:4096 -r 127.0.0.1:51820 -k "vpnchain_secret" -f1:2 --mode 1 --timeout 5 --mtu 1280
    network_mode: host
    restart: unless-stopped

  # 3. udp2raw Sunucusu (Dış Port: 4097 TCP -> İç WireGuard: 127.0.0.1:51820)
  udp2raw:
    image: wangyu-/udp2raw:latest
    container_name: vpnchain_udp2raw
    cap_add:
      - NET_ADMIN
    command: -s -l 0.0.0.0:4097 -r 127.0.0.1:51820 -k "vpnchain_secret" --raw-mode faketcp --cipher-mode aes128cbc --seq-mode 3 --fix-gro
    network_mode: host
    restart: unless-stopped
```

Başlatmak için VPS üzerinde:
```bash
docker compose up -d
```

---

## 🚀 Derleme ve Geliştirme

### Gereksinimler:
- Flutter SDK (3.22+)
- Xcode 15+ (macOS/iOS için)
- Android SDK (API 34+)

```bash
# Bağımlılıkları yükleyin
flutter pub get

# Testleri çalıştırın
flutter test

# macOS uygulamasını derleyin
flutter build macos

# Android APK derleyin
flutter build apk --release

# iOS uygulamasını derleyin
flutter build ios --no-codesign
```

---

# 🇬🇧 English Documentation

## 🎯 Purpose & Problem Statement

Internet Service Providers (ISPs) in censored regions employ **Deep Packet Inspection (DPI)** to classify and throttle or drop encrypted VPN tunnels.

Standard WireGuard UDP packets carry fixed, identifiable signatures:
- Handshake Initiation (`0x01`, 148 bytes)
- Handshake Response (`0x02`, 92 bytes)
- Transport Data (`0x04`)

ISPs immediately drop these packets, preventing handshakes from completing.

**VPNChain** solves this by routing all WireGuard traffic locally through `127.0.0.1:<local_port>` into a high-performance obfuscation engine (UDPspeeder or udp2raw). The payload is mathematically scrambled, stripped of WireGuard headers, and transmitted as generic scrambled UDP or simulated TCP streams.

## ✨ Key Features
- **2 Operational Modes**: UDPspeeder (FEC & packet recovery) and udp2raw (FakeTCP simulated handshake).
- **Cross-Platform**: macOS (15+), iOS (15+), Windows (7+), Android (5.0+).
- **Built-in Pure Dart Core**: Zero root required, sandboxed Apple platform compliant.
- **Native Process Runner**: Optional execution of official `speederv2` and `udp2raw` binaries.
- **WireGuard Config Box**: Paste `.conf`, import files, auto-extract server IP and adjust MTU (1280).
- **Live Diagnostics**: Real-time TX/RX speeds, ping latency, session bandwidth, and live console logs.
- **Profile Management**: Import/Export `.vpnchain` and legacy `.selconf` profile bundles.

## 📄 License
MIT License. Core UDPspeeder and udp2raw projects belong to their respective authors (Wang Yu).
