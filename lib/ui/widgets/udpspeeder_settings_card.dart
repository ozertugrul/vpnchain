import 'package:flutter/material.dart';
import '../../models/udpspeeder_config.dart';
import '../theme/app_theme.dart';

class UdpSpeederSettingsCard extends StatefulWidget {
  final UdpSpeederConfig config;
  final ValueChanged<UdpSpeederConfig> onChanged;

  const UdpSpeederSettingsCard({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<UdpSpeederSettingsCard> createState() => _UdpSpeederSettingsCardState();
}

class _UdpSpeederSettingsCardState extends State<UdpSpeederSettingsCard> {
  late TextEditingController _ipCtrl;
  late TextEditingController _remotePortCtrl;
  late TextEditingController _localPortCtrl;
  late TextEditingController _passwordCtrl;
  bool _obscurePassword = true;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(text: widget.config.serverIp);
    _remotePortCtrl = TextEditingController(text: widget.config.remotePort.toString());
    _localPortCtrl = TextEditingController(text: widget.config.localPort.toString());
    _passwordCtrl = TextEditingController(text: widget.config.password);
  }

  @override
  void didUpdateWidget(covariant UdpSpeederSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config.serverIp != _ipCtrl.text) {
      _ipCtrl.text = widget.config.serverIp;
    }
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _remotePortCtrl.dispose();
    _localPortCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged(
      widget.config.copyWith(
        serverIp: _ipCtrl.text.trim(),
        remotePort: int.tryParse(_remotePortCtrl.text.trim()) ?? 28001,
        localPort: int.tryParse(_localPortCtrl.text.trim()) ?? 1234,
        password: _passwordCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed_rounded, color: AppTheme.cyanNeon, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'UDPspeeder Settings',
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
                    color: AppTheme.cyanNeon.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cyanNeon.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'FEC & OBFS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cyanNeon,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Server IP & Remote Port Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ipCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Server IP / Host',
                      hintText: 'e.g. 198.51.100.1',
                      prefixIcon: Icon(Icons.cloud_outlined, size: 18),
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _remotePortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Remote Port',
                      hintText: '28001',
                      helperText: 'Sunucu portu',
                      prefixIcon: Icon(Icons.input_rounded, size: 18),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _notifyChange();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Local Port & Password Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _localPortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Local Port',
                      hintText: '1234',
                      helperText: 'Cihaz içi port',
                      errorText: (_localPortCtrl.text.trim() == _remotePortCtrl.text.trim() &&
                              _localPortCtrl.text.trim().isNotEmpty)
                          ? 'Remote ile aynı olamaz'
                          : null,
                      prefixIcon: const Icon(Icons.router_outlined, size: 18),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _notifyChange();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password / Key',
                      hintText: 'Secret cipher key',
                      prefixIcon: const Icon(Icons.key_rounded, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // FEC Preset Selection
            const Text(
              'Forward Error Correction (FEC) Profile',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1322),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderDark),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<UdpSpeederPreset>(
                  value: widget.config.preset,
                  isExpanded: true,
                  dropdownColor: AppTheme.cardDark,
                  icon: const Icon(Icons.arrow_drop_down, color: AppTheme.cyanNeon),
                  items: UdpSpeederPreset.values.map((preset) {
                    return DropdownMenuItem<UdpSpeederPreset>(
                      value: preset,
                      child: Text(
                        preset.displayName,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (newPreset) {
                    if (newPreset != null) {
                      widget.onChanged(widget.config.copyWith(preset: newPreset));
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Toggle Advanced
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAdvanced = !_showAdvanced;
                  });
                },
                icon: Icon(
                  _showAdvanced ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: const Color(0xFF94A3B8),
                ),
                label: Text(
                  _showAdvanced ? 'Hide Advanced' : 'Advanced Parameters',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ),

            if (_showAdvanced) ...[
              const Divider(color: AppTheme.borderDark),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'MTU: ${widget.config.mtu} (Recommended: 1280)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Timeout: ${widget.config.timeout}s',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'CLI Params: ${widget.config.buildCliParams()}',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
