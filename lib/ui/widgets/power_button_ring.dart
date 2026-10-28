import 'package:flutter/material.dart';
import '../../models/vpn_stats.dart';
import '../theme/app_theme.dart';

class PowerButtonRing extends StatefulWidget {
  final VpnStatus status;
  final VoidCallback onTap;

  const PowerButtonRing({
    super.key,
    required this.status,
    required this.onTap,
  });

  @override
  State<PowerButtonRing> createState() => _PowerButtonRingState();
}

class _PowerButtonRingState extends State<PowerButtonRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case VpnStatus.connected:
        return AppTheme.greenActive;
      case VpnStatus.connecting:
      case VpnStatus.reconnecting:
      case VpnStatus.disconnecting:
        return AppTheme.amberWarning;
      case VpnStatus.error:
        return AppTheme.redError;
      case VpnStatus.disconnected:
        return AppTheme.cyanNeon;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.status) {
      case VpnStatus.connected:
        return Icons.shield;
      case VpnStatus.connecting:
      case VpnStatus.reconnecting:
      case VpnStatus.disconnecting:
        return Icons.sync;
      case VpnStatus.error:
        return Icons.warning_amber_rounded;
      case VpnStatus.disconnected:
        return Icons.power_settings_new_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final isConnected = widget.status == VpnStatus.connected;
    final isTransitioning = widget.status.isTransitioning;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = (isConnected || isTransitioning) ? _pulseAnimation.value : 1.0;

        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F172A),
                    border: Border.all(
                      color: color.withValues(alpha: 0.5),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: isConnected ? 0.4 : 0.15),
                        blurRadius: isConnected ? 32 : 16,
                        spreadRadius: isConnected ? 6 : 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: isTransitioning
                        ? SizedBox(
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.5,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          )
                        : Icon(
                            _getStatusIcon(),
                            size: 64,
                            color: color,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  widget.status.displayName.toUpperCase(),
                  key: ValueKey(widget.status),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isConnected
                    ? 'Tap to Disconnect'
                    : isTransitioning
                        ? 'Establishing Secure Chained Tunnel...'
                        : 'Tap to Connect',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
