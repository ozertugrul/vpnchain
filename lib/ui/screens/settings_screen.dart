import 'package:flutter/material.dart';
import '../../services/tunnel/tunnel_orchestrator.dart';
import '../../services/vpn_manager.dart';
import '../theme/app_theme.dart';

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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.cyanNeon.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shield_outlined, color: AppTheme.cyanNeon, size: 24),
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
                                'Version 2.0.0 (Flutter Edition)',
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
