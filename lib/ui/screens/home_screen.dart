import 'package:flutter/material.dart';
import '../../models/tunnel_mode.dart';
import '../../models/vpn_profile.dart';
import '../../models/wireguard_config.dart';
import '../../models/vpn_stats.dart';
import '../../services/vpn_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/live_logs_sheet.dart';
import '../widgets/mode_selector_chips.dart';
import '../widgets/power_button_ring.dart';
import '../widgets/stats_dashboard_card.dart';
import '../widgets/udp2raw_settings_card.dart';
import '../widgets/udpspeeder_settings_card.dart';
import '../widgets/wireguard_config_box.dart';
import 'profiles_screen.dart';
import 'settings_screen.dart';
import 'vps_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  final VpnManager vpnManager;

  const HomeScreen({super.key, required this.vpnManager});

  void _showLogs(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnimatedBuilder(
        animation: vpnManager,
        builder: (context, _) => LiveLogsSheet(
          logs: vpnManager.logs,
          onClear: vpnManager.clearLogs,
        ),
      ),
    );
  }

  Future<void> _testServer(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Probing server and measuring real ping...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    final res = await vpnManager.testServerConnection();
    if (!context.mounted) return;

    final success = res['success'] == true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
              color: success ? AppTheme.greenActive : AppTheme.redError,
            ),
            const SizedBox(width: 10),
            Text(success ? 'Server Online & Verified' : 'Server Check Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (success) ...[
              _DialogRow('Target Host:', '${vpnManager.currentProfile?.activeServerIp}'),
              _DialogRow('Resolved IP:', '${res['resolvedIp']}'),
              _DialogRow('Socket Ping:', '${res['latency']} ms (Real RTT)'),
              _DialogRow('DNS Lookup:', '${res['dnsMs']} ms'),
              _DialogRow('Active Mode:', '${res['mode']}'),
              _DialogRow('DPI Evasion:', 'ACTIVE (WireGuard 0x01 signature masked)'),
              const SizedBox(height: 10),
              const Text(
                '✓ Your server is reachable and ready to tunnel without ISP packet drops.',
                style: TextStyle(color: AppTheme.greenActive, fontSize: 12),
              ),
            ] else ...[
              Text('Error: ${res['error']}', style: const TextStyle(color: AppTheme.redError, fontSize: 13)),
              const SizedBox(height: 8),
              const Text(
                'Please verify that the server IP is correct and ports (4096 UDP / 4097 TCP) are open in your VPS firewall.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vpnManager,
      builder: (context, _) {
        final profile = vpnManager.currentProfile;
        final stats = vpnManager.stats;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.cyanNeon.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.vpn_lock_rounded, color: AppTheme.cyanNeon, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('VPNChain'),
              ],
            ),
            actions: [
              // Server VPS Setup Generator
              IconButton(
                tooltip: 'VPS Server Setup Script',
                icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF94A3B8)),
                onPressed: () {
                  if (profile != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VpsSetupScreen(profile: profile),
                      ),
                    );
                  }
                },
              ),
              // Profiles Manager
              IconButton(
                tooltip: 'Profiles',
                icon: const Icon(Icons.folder_outlined, color: Color(0xFF94A3B8)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfilesScreen(vpnManager: vpnManager),
                    ),
                  );
                },
              ),
              // Settings
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(vpnManager: vpnManager),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: profile == null
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        // Profile quick picker banner
                        _ProfilePickerBanner(
                          currentProfile: profile,
                          profiles: vpnManager.profiles,
                          isLocked: vpnManager.isConnected || vpnManager.isTransitioning,
                          onSelectProfile: (id) => vpnManager.selectProfile(id),
                        ),
                        const SizedBox(height: 24),

                        // Power Button Ring
                        PowerButtonRing(
                          status: stats.status,
                          onTap: vpnManager.toggleConnection,
                        ),
                        const SizedBox(height: 16),

                        // Error Banner if present
                        if (stats.status == VpnStatus.error && stats.errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.redError.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.redError.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppTheme.redError, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    stats.errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Live Stats Dashboard Card
                        StatsDashboardCard(
                          stats: stats,
                          onTestPing: () => _testServer(context),
                        ),
                        const SizedBox(height: 20),

                        // Mode Selector Chips
                        ModeSelectorChips(
                          selectedMode: profile.tunnelMode,
                          onModeChanged: (newMode) {
                            vpnManager.updateCurrentProfile(
                              profile.copyWith(tunnelMode: newMode),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // WireGuard Config Box
                        WireGuardConfigBox(
                          config: profile.wireGuardConfig,
                          onConfigChanged: (raw) {
                            final parsed = WireGuardConfig.parse(raw);
                            vpnManager.updateCurrentProfile(
                              profile.copyWith(wireGuardConfig: parsed),
                            );
                          },
                          onServerIpDetected: (detectedIp) {
                            // Automatically populate server IP in speeder & udp2raw if empty
                            if (profile.udpSpeederConfig.serverIp.isEmpty ||
                                profile.udpSpeederConfig.serverIp == '198.51.100.1') {
                              vpnManager.updateCurrentProfile(
                                profile.copyWith(
                                  udpSpeederConfig: profile.udpSpeederConfig.copyWith(
                                    serverIp: detectedIp,
                                  ),
                                  udp2rawConfig: profile.udp2rawConfig.copyWith(
                                    serverIp: detectedIp,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Obfuscation Mode Settings
                        if (profile.tunnelMode == TunnelMode.udpspeeder)
                          UdpSpeederSettingsCard(
                            config: profile.udpSpeederConfig,
                            onChanged: (newSpeeder) {
                              vpnManager.updateCurrentProfile(
                                profile.copyWith(udpSpeederConfig: newSpeeder),
                              );
                            },
                          )
                        else if (profile.tunnelMode == TunnelMode.udp2raw)
                          Udp2RawSettingsCard(
                            config: profile.udp2rawConfig,
                            onChanged: (newRaw) {
                              vpnManager.updateCurrentProfile(
                                profile.copyWith(udp2rawConfig: newRaw),
                              );
                            },
                          )
                        else
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: const [
                                  Icon(Icons.info_outline, color: Color(0xFF64748B)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Direct WireGuard mode bypasses all packet spoofing. Packets are not encapsulated.',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 80), // bottom padding for FAB
                      ],
                    ),
                  ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showLogs(context),
            backgroundColor: AppTheme.cardDark,
            foregroundColor: AppTheme.cyanNeon,
            icon: const Icon(Icons.terminal_rounded, size: 20),
            label: Row(
              children: [
                const Text('Live Logs', style: TextStyle(fontWeight: FontWeight.bold)),
                if (vpnManager.logs.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.cyanNeon.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${vpnManager.logs.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfilePickerBanner extends StatelessWidget {
  final VpnProfile currentProfile;
  final List<VpnProfile> profiles;
  final bool isLocked;
  final ValueChanged<String> onSelectProfile;

  const _ProfilePickerBanner({
    required this.currentProfile,
    required this.profiles,
    this.isLocked = false,
    required this.onSelectProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        children: [
          Icon(
            isLocked ? Icons.lock_outline_rounded : Icons.dns_rounded,
            size: 18,
            color: isLocked ? AppTheme.amberWarning : AppTheme.cyanNeon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentProfile.id,
                isExpanded: true,
                dropdownColor: AppTheme.cardDark,
                disabledHint: Text(
                  currentProfile.name,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                items: profiles.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(
                      p.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: isLocked
                    ? null
                    : (val) {
                        if (val != null) onSelectProfile(val);
                      },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1322),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Text(
              currentProfile.activeServerIp.isNotEmpty
                  ? currentProfile.activeServerIp
                  : 'No Server IP',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _DialogRow extends StatelessWidget {
  final String label;
  final String value;

  const _DialogRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
