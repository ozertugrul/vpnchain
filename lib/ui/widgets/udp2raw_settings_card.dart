import 'package:flutter/material.dart';
import '../../models/udp2raw_config.dart';
import '../theme/app_theme.dart';

class Udp2RawSettingsCard extends StatefulWidget {
  final Udp2RawConfig config;
  final ValueChanged<Udp2RawConfig> onChanged;

  const Udp2RawSettingsCard({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<Udp2RawSettingsCard> createState() => _Udp2RawSettingsCardState();
}

class _Udp2RawSettingsCardState extends State<Udp2RawSettingsCard> {
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
  void didUpdateWidget(covariant Udp2RawSettingsCard oldWidget) {
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
        remotePort: int.tryParse(_remotePortCtrl.text.trim()) ?? 8080,
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
                const Icon(Icons.layers_rounded, color: AppTheme.purpleNeon, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'udp2raw Settings',
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
                    color: AppTheme.purpleNeon.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.purpleNeon.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'FakeTCP & DPI EVASION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.purpleNeon,
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
                      hintText: '8080',
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

            // Raw Mode Selection
            const Text(
              'Encapsulation Mode (raw-mode)',
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
                child: DropdownButton<RawMode>(
                  value: widget.config.rawMode,
                  isExpanded: true,
                  dropdownColor: AppTheme.cardDark,
                  icon: const Icon(Icons.arrow_drop_down, color: AppTheme.purpleNeon),
                  items: RawMode.values.map((mode) {
                    return DropdownMenuItem<RawMode>(
                      value: mode,
                      child: Text(
                        mode.displayName,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (newMode) {
                    if (newMode != null) {
                      widget.onChanged(widget.config.copyWith(rawMode: newMode));
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cipher Mode', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        DropdownButton<CipherMode>(
                          value: widget.config.cipherMode,
                          isExpanded: true,
                          dropdownColor: AppTheme.cardDark,
                          items: CipherMode.values.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(fontSize: 12)));
                          }).toList(),
                          onChanged: (c) {
                            if (c != null) widget.onChanged(widget.config.copyWith(cipherMode: c));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fix GRO', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        Switch(
                          value: widget.config.fixGro,
                          activeThumbColor: AppTheme.purpleNeon,
                          onChanged: (v) => widget.onChanged(widget.config.copyWith(fixGro: v)),
                        ),
                      ],
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
