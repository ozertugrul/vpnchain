import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/log_entry.dart';
import '../theme/app_theme.dart';

class LiveLogsSheet extends StatefulWidget {
  final List<LogEntry> logs;
  final VoidCallback onClear;

  const LiveLogsSheet({
    super.key,
    required this.logs,
    required this.onClear,
  });

  @override
  State<LiveLogsSheet> createState() => _LiveLogsSheetState();
}

class _LiveLogsSheetState extends State<LiveLogsSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _filter = '';

  @override
  void didUpdateWidget(covariant LiveLogsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.logs.length != oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _copyAll() {
    final text = widget.logs.map((e) => e.toFullString()).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All logs copied to clipboard!')),
    );
  }

  Color _getTagColor(String tag, LogLevel level) {
    if (level == LogLevel.error) return AppTheme.redError;
    if (level == LogLevel.warning) return AppTheme.amberWarning;
    if (tag.contains('WireGuard')) return AppTheme.greenActive;
    if (tag.contains('Tunnel') || tag.contains('UDPspeeder') || tag.contains('udp2raw')) {
      return AppTheme.cyanNeon;
    }
    return const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filter.isEmpty
        ? widget.logs
        : widget.logs
            .where((l) =>
                l.message.toLowerCase().contains(_filter.toLowerCase()) ||
                l.tag.toLowerCase().contains(_filter.toLowerCase()))
            .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF070B14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1.5)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Sheet Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, color: AppTheme.cyanNeon, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Live Tunnel Console',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _autoScroll ? 'Disable Auto-scroll' : 'Enable Auto-scroll',
                  icon: Icon(
                    _autoScroll ? Icons.vertical_align_bottom : Icons.pause_circle_outline,
                    color: _autoScroll ? AppTheme.cyanNeon : const Color(0xFF64748B),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _autoScroll = !_autoScroll),
                ),
                IconButton(
                  tooltip: 'Copy Logs',
                  icon: const Icon(Icons.copy_rounded, color: Color(0xFF94A3B8), size: 20),
                  onPressed: _copyAll,
                ),
                IconButton(
                  tooltip: 'Clear Logs',
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                  onPressed: widget.onClear,
                ),
              ],
            ),
          ),
          // Filter search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filter logs (e.g. handshake, error)...',
                prefixIcon: const Icon(Icons.search, size: 16),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => _filter = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.borderDark, height: 1),

          // Log list
          Expanded(
            child: filteredLogs.isEmpty
                ? const Center(
                    child: Text(
                      'No logs yet. Connect to begin streaming console output.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      final tagColor = _getTagColor(log.tag, log.level);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              color: Color(0xFFE2E8F0),
                              height: 1.35,
                            ),
                            children: [
                              TextSpan(
                                text: '[${log.formatTime()}] ',
                                style: const TextStyle(color: Color(0xFF475569)),
                              ),
                              TextSpan(
                                text: '${log.tag} ',
                                style: TextStyle(
                                  color: tagColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: log.message,
                                style: TextStyle(
                                  color: log.level == LogLevel.error
                                      ? AppTheme.redError
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
