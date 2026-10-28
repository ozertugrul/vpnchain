import 'package:flutter/material.dart';
import '../../models/vpn_stats.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class StatsDashboardCard extends StatelessWidget {
  final VpnStats stats;
  final VoidCallback? onTestPing;

  const StatsDashboardCard({
    super.key,
    required this.stats,
    this.onTestPing,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = stats.status == VpnStatus.connected;
    final isTransitioning = stats.status.isTransitioning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Status Pill & Test Ping Button
            Row(
              children: [
                Flexible(
                  child: _StatusBadge(status: stats.status, handshake: stats.handshakeStatus),
                ),
                const SizedBox(width: 8),
                if (onTestPing != null)
                  TextButton.icon(
                    onPressed: onTestPing,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppTheme.cyanNeon,
                    ),
                    icon: const Icon(Icons.network_ping_rounded, size: 16),
                    label: const Text('Test Ping', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Speed Indicators Row
            Row(
              children: [
                Expanded(
                  child: _SpeedMeter(
                    label: 'DOWNLOAD SPEED',
                    speed: stats.downloadSpeed,
                    totalBytes: stats.totalDownload,
                    packets: stats.rxPackets,
                    icon: Icons.arrow_downward_rounded,
                    color: AppTheme.greenActive,
                    isActive: stats.downloadSpeed > 0,
                  ),
                ),
                Container(
                  height: 60,
                  width: 1,
                  color: AppTheme.borderDark,
                ),
                Expanded(
                  child: _SpeedMeter(
                    label: 'UPLOAD SPEED',
                    speed: stats.uploadSpeed,
                    totalBytes: stats.totalUpload,
                    packets: stats.txPackets,
                    icon: Icons.arrow_upward_rounded,
                    color: AppTheme.cyanNeon,
                    isActive: stats.uploadSpeed > 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Live Traffic Waveform Chart (Active when connected)
            if (isConnected || stats.totalDownload > 0 || stats.totalUpload > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    'LIVE TRAFFIC WAVEFORM (KB/s)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  _ChartLegend(color: AppTheme.greenActive, label: 'RX ↓'),
                  const SizedBox(width: 10),
                  _ChartLegend(color: AppTheme.cyanNeon, label: 'TX ↑'),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 52,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF090E1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: CustomPaint(
                  painter: _LiveWaveformPainter(
                    downHistory: stats.speedHistoryDown,
                    upHistory: stats.speedHistoryUp,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const Divider(color: AppTheme.borderDark, height: 16),

            // Bottom Diagnostics Row: Ping, Uptime, Packets
            Row(
              children: [
                Expanded(
                  child: _DiagBadge(
                    icon: Icons.network_ping_rounded,
                    label: 'Server Ping',
                    value: stats.pingMs > 0 ? '${stats.pingMs} ms' : (isTransitioning ? 'Probing...' : '--'),
                    color: stats.pingMs > 0 && stats.pingMs < 80
                        ? AppTheme.greenActive
                        : stats.pingMs < 160
                            ? AppTheme.amberWarning
                            : AppTheme.redError,
                  ),
                ),
                Expanded(
                  child: _DiagBadge(
                    icon: Icons.timer_outlined,
                    label: 'Uptime',
                    value: Formatters.formatDuration(stats.uptimeSeconds),
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: _DiagBadge(
                    icon: Icons.all_inbox_rounded,
                    label: 'Total Packets',
                    value: '${stats.rxPackets} ↓ / ${stats.txPackets} ↑',
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final VpnStatus status;
  final HandshakeStatus handshake;

  const _StatusBadge({required this.status, required this.handshake});

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFF1E293B);
    Color border = const Color(0xFF334155);
    Color textCol = const Color(0xFF94A3B8);
    String label = status.displayName.toUpperCase();

    if (status == VpnStatus.connected) {
      bg = AppTheme.greenActive.withValues(alpha: 0.15);
      border = AppTheme.greenActive;
      textCol = AppTheme.greenActive;
      label = handshake == HandshakeStatus.confirmed
          ? 'PROTECTED • HANDSHAKE OK'
          : 'CONNECTED';
    } else if (status.isTransitioning) {
      bg = AppTheme.amberWarning.withValues(alpha: 0.15);
      border = AppTheme.amberWarning;
      textCol = AppTheme.amberWarning;
    } else if (status == VpnStatus.error) {
      bg = AppTheme.redError.withValues(alpha: 0.15);
      border = AppTheme.redError;
      textCol = AppTheme.redError;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: textCol,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textCol,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedMeter extends StatelessWidget {
  final String label;
  final int speed;
  final int totalBytes;
  final int packets;
  final IconData icon;
  final Color color;
  final bool isActive;

  const _SpeedMeter({
    required this.label,
    required this.speed,
    required this.totalBytes,
    required this.packets,
    required this.icon,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isActive ? 0.25 : 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? color : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          Formatters.formatSpeed(speed),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Total: ${Formatters.formatBytes(totalBytes)}',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _DiagBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DiagBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

class _LiveWaveformPainter extends CustomPainter {
  final List<double> downHistory;
  final List<double> upHistory;

  _LiveWaveformPainter({required this.downHistory, required this.upHistory});

  @override
  void paint(Canvas canvas, Size size) {
    if (downHistory.isEmpty && upHistory.isEmpty) return;

    final maxVal = [
      ...downHistory,
      ...upHistory,
      10.0, // minimum scale
    ].reduce((a, b) => a > b ? a : b);

    _paintCurve(canvas, size, downHistory, AppTheme.greenActive, maxVal);
    _paintCurve(canvas, size, upHistory, AppTheme.cyanNeon, maxVal);
  }

  void _paintCurve(Canvas canvas, Size size, List<double> points, Color color, double maxVal) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final norm = (points[i] / maxVal).clamp(0.0, 1.0);
      final y = size.height - (norm * (size.height - 4)) - 2;
      final x = i * stepX;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter oldDelegate) => true;
}
