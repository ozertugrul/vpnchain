import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/wireguard_config.dart';
import '../theme/app_theme.dart';

class WireGuardConfigBox extends StatefulWidget {
  final WireGuardConfig config;
  final ValueChanged<String> onConfigChanged;
  final ValueChanged<String>? onServerIpDetected;

  const WireGuardConfigBox({
    super.key,
    required this.config,
    required this.onConfigChanged,
    this.onServerIpDetected,
  });

  @override
  State<WireGuardConfigBox> createState() => _WireGuardConfigBoxState();
}

class _WireGuardConfigBoxState extends State<WireGuardConfigBox> {
  late TextEditingController _controller;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.config.rawConfig);
  }

  @override
  void didUpdateWidget(covariant WireGuardConfigBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config.rawConfig != _controller.text) {
      _controller.text = widget.config.rawConfig;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChange(String text) {
    widget.onConfigChanged(text);
    final parsed = WireGuardConfig.parse(text);
    if (parsed.serverHost.isNotEmpty) {
      widget.onServerIpDetected?.call(parsed.serverHost);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _controller.text = data.text!;
      _handleTextChange(data.text!);
    }
  }

  Future<void> _pickConfigFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['conf', 'txt', 'selconf'],
      );
      if (files.isNotEmpty) {
        final path = files.first.path;
        if (path != null) {
          final text = await File(path).readAsString();
          _controller.text = text;
          _handleTextChange(text);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = WireGuardConfig.parse(_controller.text);
    final isValid = parsed.isValid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.code_rounded, color: AppTheme.cyanNeon, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'WireGuard Configuration',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isValid
                        ? AppTheme.greenActive.withValues(alpha: 0.15)
                        : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isValid ? AppTheme.greenActive : const Color(0xFF475569),
                    ),
                  ),
                  child: Text(
                    isValid ? 'VALID' : 'EMPTY / INCOMPLETE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isValid ? AppTheme.greenActive : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isValid && parsed.endpoint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.dns_outlined, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(
                      'Endpoint: ${parsed.endpoint}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _controller,
              maxLines: _isExpanded ? 16 : 6,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: Color(0xFFE2E8F0),
              ),
              decoration: const InputDecoration(
                hintText:
                    '[Interface]\nPrivateKey = ...\nAddress = 10.0.0.2/24\nDNS = 1.1.1.1\n\n[Peer]\nPublicKey = ...\nEndpoint = 198.51.100.1:51820\nAllowedIPs = 0.0.0.0/0',
              ),
              onChanged: _handleTextChange,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text('Paste'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickConfigFile,
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('Import .conf'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _isExpanded ? 'Collapse' : 'Expand Editor',
                  icon: Icon(
                    _isExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    color: const Color(0xFF94A3B8),
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
                if (_controller.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      _controller.clear();
                      _handleTextChange('');
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
