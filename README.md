<div align="center">
  <img src="app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" width="150" alt="VPNChain Logo" />
  
  # VPNChain 🚀
  
  **Ultimate Android VPN Client Chaining WireGuard with UDPspeeder**
  
  [![Android](https://img.shields.io/badge/Android-10.0%2B-green.svg)](https://android.com)
  [![Kotlin](https://img.shields.io/badge/Kotlin-1.9.0-blue.svg)](https://kotlinlang.org)
  [![Jetpack Compose](https://img.shields.io/badge/Jetpack_Compose-Latest-teal.svg)](https://developer.android.com/jetpack/compose)
  [![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)
</div>

<br/>

**VPNChain**, zayıf ve kısıtlı internet bağlantılarında (özellikle yüksek paket kaybı olan veya UDP trafiğinin kısıtlandığı ağlarda) kesintisiz bir deneyim sunmak için tasarlanmış yenilikçi bir Android VPN uygulamasıdır. 

Uygulama, **WireGuard** protokolünün hızını ve güvenliğini, **UDPspeeder**'ın (Forward Error Correction - FEC) paket kurtarma yeteneğiyle birleştirir. Tüm WireGuard trafiğiniz yerel cihazda bir UDPspeeder istemcisinden geçirilir ve böylece dalgalı Wi-Fi veya 4G/5G bağlantılarında dahi inanılmaz stabilite sağlanır!

---

## ✨ Özellikler

* 🛡️ **WireGuard + UDPspeeder Zinciri**: WireGuard paketleri, UDPspeeder üzerinden tünellenerek paket kayıplarına karşı korunur.
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
