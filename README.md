<div align="center">
  <img src="app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" width="150" alt="VPNChain Logo" />
  
  # VPNChain 🚀
  
  **Ultimate Android VPN Client Chaining WireGuard with UDPspeeder**
  
  [![Android](https://img.shields.io/badge/Android-10.0%2B-green.svg)](https://android.com)
  [![Kotlin](https://img.shields.io/badge/Kotlin-1.9.0-blue.svg)](https://kotlinlang.org)
  [![Jetpack Compose](https://img.shields.io/badge/Jetpack_Compose-Latest-teal.svg)](https://developer.android.com/jetpack/compose)
  [![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)
</div>

*🇹🇷 [Türkçe (Turkish) Sürüm](#vpnchain-) | 🇬🇧 [English Version Below](#-english-version)*

<br/>

**VPNChain**, zayıf ve kısıtlı internet bağlantılarında (özellikle yüksek paket kaybı olan, UDP trafiğinin kısıtlandığı veya İSS/ISP engellerinin bulunduğu ağlarda) kesintisiz bir deneyim ve özgürlük sunmak için tasarlanmış yenilikçi bir Android VPN uygulamasıdır. 

Uygulama, **WireGuard** protokolünün hızını ve güvenliğini, **UDPspeeder**'ın (Forward Error Correction - FEC) paket kurtarma yeteneğiyle birleştirir. Tüm WireGuard trafiğiniz yerel cihazda bir UDPspeeder istemcisinden geçirilerek maskelenir. Bu sayede hem servis sağlayıcıların (İSS) koyduğu katı sansürler ve hız sınırlandırmaları (throttling) aşılır, hem de dalgalı Wi-Fi veya 4G/5G bağlantılarında inanılmaz bir stabilite sağlanır!

---

## ⚠️ Önemli Ön Koşullar

Bu uygulama tek başına bir VPN hizmeti sunmaz, **sadece bir istemcidir (client)**. Uygulamayı kullanabilmeniz için önceden kurulmuş ve çalışır durumda olan:
1. Bir **WireGuard Sunucusuna**,
2. WireGuard trafiğini sarmalayacak bir **UDPspeeder Sunucusuna** (VPS üzerinde çalıştırılan) ihtiyacınız vardır.

---

## ✨ Özellikler

* 🛡️ **WireGuard + UDPspeeder Zinciri & İSS Atlatma**: WireGuard paketleri, UDPspeeder üzerinden maskelenip tünellenerek katı İSS (Servis Sağlayıcı) engellerine karşı görünmez kılınır ve paket kayıpları engellenir.
* ⚡ **Jetpack Compose Arayüzü**: Modern, hızlı ve Material You (Material 3) uyumlu, pürüzsüz kullanıcı arayüzü.
* 🔄 **Kalıcı Arka Plan Servisi (FGS)**: Android Doze modundan etkilenmeyen Foreground Service ve kalıcı bildirim çubuğu.
* 📊 **Canlı İstatistikler**: Saniye saniye güncellenen TX/RX hızları, oturum bazlı trafik ve tüm zamanların bant genişliği takibi.
* ⚙️ **Profil Yönetimi**: `*.selconf` formatında konfigürasyonları JSON olarak içe/dışa aktarabilme.
* 📜 **Canlı Loglar (Logcat)**: WireGuard'ın (GoBackend) ve UDPspeeder'ın tüm CLI çıktılarını eşzamanlı ve anlık olarak uygulama içinden izleme imkanı.

---

## 🛠️ Nasıl Çalışır? (Mimari)

VPNChain, resmi `wireguard-android` SDK'sı içerisindeki GoBackend altyapısını kullanır. 
1. Uygulama, belirtilen ayarlarla cihazınızda yerel bir UDPspeeder süreci (subprocess) başlatır.
2. WireGuard tüneli açılırken hedef IP olarak sunucunuzun IP'si yerine, UDPspeeder'ın yerel portu (örn: `127.0.0.1:1234`) gösterilir.
3. Çakışmaları ve sonsuz döngüleri önlemek için UDPspeeder'ın oluşturduğu soketler `VpnService.protect()` kullanılarak VPN'den muaf tutulur.

### 🎛️ UDPspeeder Çalışma Parametreleri

Uygulama, ağ durumunuza göre iki farklı hazır profil sunar:

**1. Normal Mode (Düşük Gecikme)**
Herhangi bir paket çoklaması yapmaz, sadece UDP trafiğini maskeler ve tüneller.
```bash
# Kullanılan Argüman:
-c -l 0.0.0.0:[LOCAL_PORT] -r [SERVER_IP]:[REMOTE_PORT] --mode 1 --timeout 5
```

**2. FEC Mode (Forward Error Correction - Paket Kurtarma)**
Yüksek paket kaybı olan ağlar için uygundur. Her 2 pakette 1 ekstra kurtarma paketi (f1:2) yollanır. Gecikme biraz artar ama bağlantı kararlılığı maksimize edilir.
```bash
# Kullanılan Argüman:
-c -l 0.0.0.0:[LOCAL_PORT] -r [SERVER_IP]:[REMOTE_PORT] -f1:2 --mode 1 --timeout 5
```

> **Not:** WireGuard paketlerinin (MTU) UDPspeeder başlık (header) verileriyle sığabilmesi için uygulamanın içinde WireGuard `MTU` değeri otomatik olarak **1280**'e düşürülür.

---

## 🚀 Kurulum & Derleme

Uygulama, modern Android araçlarıyla geliştirilmiştir.

1. Projeyi klonlayın:
   ```bash
   git clone https://github.com/username/VPNChain.git
   ```
2. Android Studio (Ladybug veya üstü önerilir) ile klasörü açın.
3. Gradle senkronizasyonunu bekleyin.
4. Cihazınıza veya emülatörünüze (API 26+) uygulamayı yükleyin.

> **Önemli:** Uygulamanın içerisinde UDPspeeder binary dosyaları (`libspeederv2.so`) cihazların mimarisine (ARM64, x86_64, armeabi-v7a) göre gömülüdür. Sistem, `AndroidManifest.xml` içerisindeki `android:extractNativeLibs="true"` sayesinde bu binaryleri çıkartıp çalıştırmaktadır. JNI hatası yaşamazsınız.

---

## 🤝 Katkıda Bulunma

Her türlü Pull Request (PR) ve Issue açılışına açığız. Lütfen kod eklerken Compose mimarisine ve MVVM yapısına sadık kalmaya özen gösterin.

## 📄 Lisans

Bu proje **MIT Lisansı** altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakabilirsiniz. 
*UDPspeeder ve WireGuard'ın kendi çekirdek projeleri kendi lisanslarına (GPL/MIT vb.) tabidir.*

---
<br/>

# 🇬🇧 English Version

**VPNChain** is an innovative Android VPN application designed to provide a seamless experience and digital freedom on weak and restricted internet connections (especially networks with high packet loss, UDP throttling, or strict ISP blocking/censorship).

The application combines the speed and security of the **WireGuard** protocol with the packet recovery capability of **UDPspeeder** (Forward Error Correction - FEC). All your WireGuard traffic is obfuscated and tunneled through a local UDPspeeder client on your device. This effectively bypasses Internet Service Provider (ISP) restrictions and throttling, while ensuring incredible stability even on fluctuating Wi-Fi or 4G/5G connections!

---

## ⚠️ Important Prerequisites

This application does not provide a standalone VPN service; it is **only a client**. To use the application, you must have the following already set up and running:
1. A **WireGuard Server**,
2. A **UDPspeeder Server** (running on a VPS) to encapsulate the WireGuard traffic.

---

## ✨ Features

* 🛡️ **WireGuard + UDPspeeder Chain & ISP Bypass**: WireGuard packets are obfuscated and tunneled through UDPspeeder, masking them from strict ISP censorship/blocking while protecting against packet loss.
* ⚡ **Jetpack Compose UI**: Modern, fast, Material You (Material 3) compliant, smooth user interface.
* 🔄 **Persistent Background Service (FGS)**: Android Doze-mode resistant Foreground Service and persistent notification bar.
* 📊 **Live Statistics**: TX/RX speeds updated every second, session-based traffic, and all-time bandwidth tracking.
* ⚙️ **Profile Management**: Import/Export configurations in `*.selconf` format as JSON.
* 📜 **Live Logs (Logcat)**: Monitor all CLI outputs of WireGuard (GoBackend) and UDPspeeder simultaneously and in real-time from within the app.

---

## 🛠️ How it Works (Architecture)

VPNChain uses the GoBackend infrastructure within the official `wireguard-android` SDK.
1. The app starts a local UDPspeeder subprocess on your device with the specified settings.
2. When the WireGuard tunnel is established, the target IP is set to the local port of UDPspeeder (e.g., `127.0.0.1:1234`) instead of your server's IP.
3. To prevent conflicts and infinite loops, sockets created by UDPspeeder are exempted from the VPN using `VpnService.protect()`.

### 🎛️ UDPspeeder Operational Parameters

The application offers two built-in profiles based on your network conditions:

**1. Normal Mode (Low Latency)**
Does not duplicate any packets; it merely masks and tunnels UDP traffic.
```bash
# Argument Used:
-c -l 0.0.0.0:[LOCAL_PORT] -r [SERVER_IP]:[REMOTE_PORT] --mode 1 --timeout 5
```

**2. FEC Mode (Forward Error Correction)**
Suitable for networks with high packet loss. One extra recovery packet is sent for every 2 packets (f1:2). Latency increases slightly, but connection stability is maximized.
```bash
# Argument Used:
-c -l 0.0.0.0:[LOCAL_PORT] -r [SERVER_IP]:[REMOTE_PORT] -f1:2 --mode 1 --timeout 5
```

> **Note:** The WireGuard `MTU` value is automatically reduced to **1280** within the application so that WireGuard packets can fit inside the UDPspeeder header data.

---

## 🚀 Installation & Build

The application is developed with modern Android tools.

1. Clone the project:
   ```bash
   git clone https://github.com/username/VPNChain.git
   ```
2. Open the folder with Android Studio (Ladybug or higher recommended).
3. Wait for the Gradle sync.
4. Install the application on your device or emulator (API 26+).

> **Important:** The UDPspeeder binaries (`libspeederv2.so`) are embedded in the app according to device architectures (ARM64, x86_64, armeabi-v7a). The system extracts and runs these binaries thanks to `android:extractNativeLibs="true"` in the `AndroidManifest.xml`. You won't experience JNI errors.

---

## 🤝 Contributing

We welcome all Pull Requests (PRs) and Issues. Please make sure to adhere to the Compose architecture and MVVM pattern when adding code.

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details. 
*The core projects of UDPspeeder and WireGuard are subject to their own licenses (GPL/MIT, etc.).*
