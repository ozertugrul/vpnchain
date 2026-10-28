abstract class ObfuscationEngine {
  bool get isRunning;
  String get engineName;

  Future<void> start({
    required Function(String log) onLog,
    required Function(dynamic error) onError,
    Function(int bytesSent, int bytesReceived, bool isHandshake, bool isReply)? onPacketActivity,
  });

  Future<void> stop();
}
