enum LogLevel { info, warning, error, debug }

class LogEntry {
  final DateTime timestamp;
  final String tag;
  final String message;
  final LogLevel level;

  const LogEntry({
    required this.timestamp,
    required this.tag,
    required this.message,
    this.level = LogLevel.info,
  });

  String formatTime() {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String toFullString() {
    return '[${formatTime()}] $tag $message';
  }
}
