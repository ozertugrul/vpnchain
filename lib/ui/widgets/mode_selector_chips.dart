import 'package:flutter/material.dart';
import '../../models/tunnel_mode.dart';
import '../theme/app_theme.dart';

class ModeSelectorChips extends StatelessWidget {
  final TunnelMode selectedMode;
  final ValueChanged<TunnelMode> onModeChanged;

  const ModeSelectorChips({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        children: TunnelMode.values.map((mode) {
          final isSelected = mode == selectedMode;
          Color activeColor = AppTheme.cyanNeon;
          if (mode == TunnelMode.udp2raw) activeColor = AppTheme.purpleNeon;
          if (mode == TunnelMode.direct) activeColor = const Color(0xFF64748B);

          return Expanded(
            child: GestureDetector(
              onTap: () => onModeChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? activeColor : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          mode == TunnelMode.udpspeeder
                              ? Icons.flash_on_rounded
                              : mode == TunnelMode.udp2raw
                                  ? Icons.layers_rounded
                                  : Icons.swap_horiz_rounded,
                          size: 16,
                          color: isSelected ? activeColor : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mode == TunnelMode.udpspeeder
                              ? 'UDPspeeder'
                              : mode == TunnelMode.udp2raw
                                  ? 'udp2raw'
                                  : 'Direct',
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode == TunnelMode.udpspeeder
                          ? 'FEC & Speed'
                          : mode == TunnelMode.udp2raw
                              ? 'FakeTCP'
                              : 'Standard',
                      style: TextStyle(
                        color: isSelected ? activeColor : const Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
