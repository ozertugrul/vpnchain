import 'package:flutter/material.dart';
import '../../services/ota_update_service.dart';
import '../../services/tunnel/tunnel_orchestrator.dart';
import '../../services/vpn_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/update_dialog.dart';

class SettingsScreen extends StatelessWidget {
  final VpnManager vpnManager;

  const SettingsScreen({super.key, required this.vpnManager});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vpnManager,
      builder: (context, _) {
        final pref = vpnManager.enginePreference;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings & Info'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'OBFUSCATION ENGINE',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    _EngineOptionTile(
                      title: 'Auto (Recommended)',
                      subtitle:
                          'Automatically detects optimal engine. Uses Built-in Dart Core on iOS/macOS sandbox and native processes where supported.',
                      isSelected: pref == EnginePreference.auto,
                      onTap: () => vpnManager.setEnginePreference(EnginePreference.auto),
                    ),
                    const Divider(color: AppTheme.borderDark, height: 1),
                    _EngineOptionTile(
                      title: 'Built-in Dart Core Engine',
                      subtitle:
                          'Zero external binaries required. Pure Dart UDP socket scrambler & FEC. 100% compliant with Apple iOS/macOS sandbox and non-rooted devices.',
                      isSelected: pref == EnginePreference.builtin,
                      onTap: () => vpnManager.setEnginePreference(EnginePreference.builtin),
                    ),
                    const Divider(color: AppTheme.borderDark, height: 1),
                    _EngineOptionTile(
                      title: 'Native CLI Process',
                      subtitle:
                          'Spawns official speederv2 / udp2raw binaries for raw socket FakeTCP on Windows 7+ or rooted devices.',
                      isSelected: pref == EnginePreference.native,
                      onTap: () => vpnManager.setEnginePreference(EnginePreference.native),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'OTA GÜNCELLEMELERİ (GITHUB RELEASES)',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              const _OtaUpdateCard(),
              const SizedBox(height: 24),

              const Text(
                'ABOUT VPNCHAIN & DPI BYPASS',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'VPNChain Multi-Platform',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Version ${OtaUpdateService.currentVersion}',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Why VPNChain?\nStandard WireGuard packets carry recognizable handshake headers (0x01, 0x02, 0x04) which ISP Deep Packet Inspection (DPI) boxes detect and drop instantly.\n\nVPNChain chains WireGuard through a local obfuscation proxy (UDPspeeder with FEC or udp2raw with FakeTCP) before transmitting packets to your server. WireGuard signatures are mathematically erased, rendering your tunnel invisible to ISP censorship.',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, height: 1.4),
                      ),
                      const Divider(color: AppTheme.borderDark, height: 24),
                      const Text(
                        'Supported Platforms:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '• macOS 15+ (Sequoia & Apple Silicon/Intel)\n• iOS 15+\n• Windows 7, 8, 10, 11\n• Android 5.0+ (API 21 - 36)',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EngineOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _EngineOptionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AppTheme.cyanNeon : const Color(0xFF64748B),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtaUpdateCard extends StatelessWidget {
  const _OtaUpdateCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OtaUpdateService.instance,
      builder: (context, _) {
        final ota = OtaUpdateService.instance;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cyanNeon.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cloud_sync_rounded, color: AppTheme.cyanNeon, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GitHub Releases OTA İstemcisi',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Yüklü Sürüm: v${OtaUpdateService.currentVersion}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Yeni bir sürüm yayınlandığında doğrudan GitHub Releases üzerinden tespit edilir ve cihazınıza uygun paket (Android APK, Windows Installer veya macOS) tek dokunuşla indirilir.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.35),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: ota.isChecking
                        ? null
                        : () async {
                            final update = await ota.checkForUpdates(isManual: true);
                            if (!context.mounted) return;

                            if (update != null && update.isNewer) {
                              UpdateDialog.show(context, update);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.surfaceDark,
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: AppTheme.greenActive, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        'VPNChain güncel! (v${OtaUpdateService.currentVersion})',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ota.hasUpdate ? AppTheme.cyanNeon : const Color(0xFF1E293B),
                      foregroundColor: ota.hasUpdate ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: ota.isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            ota.hasUpdate ? Icons.download_rounded : Icons.sync_rounded,
                            size: 18,
                            color: ota.hasUpdate ? Colors.black : AppTheme.cyanNeon,
                          ),
                    label: Text(
                      ota.isChecking
                          ? 'Denetleniyor...'
                          : ota.hasUpdate
                              ? 'Yeni Sürümü İndir (${ota.availableUpdate!.tagName})'
                              : 'Güncellemeleri Denetle',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
