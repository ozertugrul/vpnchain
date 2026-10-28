import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/tunnel_mode.dart';
import '../../models/vpn_profile.dart';
import '../../models/wireguard_config.dart';
import '../../services/profile_storage_service.dart';
import '../../services/vpn_manager.dart';
import '../theme/app_theme.dart';

class ProfilesScreen extends StatelessWidget {
  final VpnManager vpnManager;

  const ProfilesScreen({super.key, required this.vpnManager});

  Future<void> _addNewProfile(BuildContext context) async {
    final nameCtrl = TextEditingController(text: 'Server ${vpnManager.profiles.length + 1}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Add New Profile'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Profile Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final newProfile = VpnProfile(
        name: nameCtrl.text.trim(),
        tunnelMode: TunnelMode.udpspeeder,
        wireGuardConfig: const WireGuardConfig(rawConfig: ''),
      );
      await vpnManager.addProfile(newProfile);
    }
  }

  Future<void> _importFile(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['vpnchain', 'selconf', 'conf', 'json', 'txt'],
      );

      if (files.isNotEmpty) {
        final path = files.first.path;
        if (path != null) {
          final content = await File(path).readAsString();
          final storage = ProfileStorageService();

          if (content.contains('[Interface]') || content.contains('[Peer]')) {
            // WireGuard INI format
            final fileName = files.first.name.replaceAll('.conf', '');
            final profile = storage.importFromWireGuardConf(content, name: fileName);
            await vpnManager.addProfile(profile);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Imported WireGuard profile: "$fileName"')),
              );
            }
          } else {
            // JSON format (.vpnchain or .selconf)
            final imported = storage.importFromJson(content);
            for (final p in imported) {
              await vpnManager.addProfile(p);
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Successfully imported ${imported.length} profile(s)!')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _exportProfile(BuildContext context, VpnProfile profile) async {
    final jsonText = profile.exportJson();
    await SharePlus.instance.share(
      ShareParams(
        text: jsonText,
        subject: '${profile.name}.vpnchain',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vpnManager,
      builder: (context, _) {
        final profiles = vpnManager.profiles;
        final activeProfile = vpnManager.currentProfile;

        return Scaffold(
          appBar: AppBar(
            title: const Text('VPN Profiles'),
            actions: [
              IconButton(
                tooltip: 'Import Profile File',
                icon: const Icon(Icons.file_download_outlined),
                onPressed: () => _importFile(context),
              ),
              IconButton(
                tooltip: 'Add Profile',
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.cyanNeon),
                onPressed: () => _addNewProfile(context),
              ),
            ],
          ),
          body: profiles.isEmpty
              ? const Center(child: Text('No profiles. Tap + to add one.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: profiles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final p = profiles[index];
                    final isActive = p.id == activeProfile?.id;

                    Color modeColor = AppTheme.cyanNeon;
                    if (p.tunnelMode == TunnelMode.udp2raw) modeColor = AppTheme.purpleNeon;
                    if (p.tunnelMode == TunnelMode.direct) modeColor = const Color(0xFF64748B);

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isActive ? AppTheme.cyanNeon : AppTheme.borderDark,
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: modeColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            p.tunnelMode == TunnelMode.udpspeeder
                                ? Icons.flash_on_rounded
                                : p.tunnelMode == TunnelMode.udp2raw
                                    ? Icons.layers_rounded
                                    : Icons.swap_horiz_rounded,
                            color: modeColor,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.cyanNeon.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: AppTheme.cyanNeon,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${p.tunnelMode.displayName} • ${p.activeServerIp.isNotEmpty ? p.activeServerIp : "No IP"}:${p.activeTargetPort}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
                          color: AppTheme.cardDark,
                          onSelected: (action) async {
                            if (action == 'select') {
                              vpnManager.selectProfile(p.id);
                              Navigator.of(context).pop();
                            } else if (action == 'export') {
                              _exportProfile(context, p);
                            } else if (action == 'duplicate') {
                              final duplicated = p.copyWith(
                                id: null,
                                name: '${p.name} (Copy)',
                                createdAt: DateTime.now(),
                              );
                              await vpnManager.addProfile(duplicated);
                            } else if (action == 'delete') {
                              if (profiles.length <= 1) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Cannot delete the only profile.')),
                                );
                                return;
                              }
                              await vpnManager.deleteProfile(p.id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'select',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline, size: 18),
                                  SizedBox(width: 8),
                                  Text('Select & Activate'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'export',
                              child: Row(
                                children: [
                                  Icon(Icons.share_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Export (.vpnchain)'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'duplicate',
                              child: Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Duplicate'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: AppTheme.redError, size: 18),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: AppTheme.redError)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          vpnManager.selectProfile(p.id);
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
