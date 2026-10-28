import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/vpn_profile.dart';
import '../../services/vps_generator_service.dart';
import '../theme/app_theme.dart';

class VpsSetupScreen extends StatefulWidget {
  final VpnProfile profile;

  const VpsSetupScreen({super.key, required this.profile});

  @override
  State<VpsSetupScreen> createState() => _VpsSetupScreenState();
}

class _VpsSetupScreenState extends State<VpsSetupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String name) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dockerText = VpsGeneratorService.generateDockerCompose(widget.profile);
    final bashText = VpsGeneratorService.generateBashScript(widget.profile);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Deployment'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.cyanNeon,
          labelColor: AppTheme.cyanNeon,
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(text: 'Docker Compose', icon: Icon(Icons.layers_outlined, size: 18)),
            Tab(text: 'Bash Script', icon: Icon(Icons.terminal_rounded, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Docker tab
          _CodeView(
            code: dockerText,
            fileName: 'docker-compose.yml',
            description:
                'Deploy WireGuard, UDPspeeder, and udp2raw simultaneously on your VPS using Docker Compose. Make sure ports are open on your VPS firewall.',
            onCopy: () => _copyToClipboard(dockerText, 'docker-compose.yml'),
          ),
          // Bash tab
          _CodeView(
            code: bashText,
            fileName: 'setup-vpnchain.sh',
            description:
                'Run this script directly on an Ubuntu/Debian VPS to install WireGuard, download the speederv2 & udp2raw binaries, enable IP forwarding, and start the background services.',
            onCopy: () => _copyToClipboard(bashText, 'setup-vpnchain.sh'),
          ),
        ],
      ),
    );
  }
}

class _CodeView extends StatelessWidget {
  final String code;
  final String fileName;
  final String description;
  final VoidCallback onCopy;

  const _CodeView({
    required this.code,
    required this.fileName,
    required this.description,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: const Color(0xFF0F172A),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.cyanNeon, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      description,
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                fileName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy to Clipboard'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF070B14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFFE2E8F0),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
