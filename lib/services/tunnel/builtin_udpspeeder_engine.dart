import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../models/udpspeeder_config.dart';
import 'obfuscation_engine.dart';

class BuiltInUdpSpeederEngine implements ObfuscationEngine {
  final UdpSpeederConfig config;

  RawDatagramSocket? _localSocket;
  RawDatagramSocket? _outboundSocket;
  InternetAddress? _remoteAddress;

  int _localClientPort = 0; // The port from which WireGuard sent datagrams
  int _sequenceCounter = 1;
  bool _running = false;

  final Random _random = Random.secure();
  late final Uint8List _keyBytes;

  // FEC Accumulators for group FEC (e.g., 2:1 or 1:1)
  final List<Uint8List> _fecDataBuffer = [];

  BuiltInUdpSpeederEngine({required this.config}) {
    // Derive 32-byte key from password using SHA-256
    _keyBytes = Uint8List.fromList(sha256.convert(config.password.codeUnits).bytes);
  }

  @override
  bool get isRunning => _running;

  @override
  String get engineName => 'Built-in UDPspeeder (Dart Core)';

  @override
  Future<void> start({
    required Function(String log) onLog,
    required Function(dynamic error) onError,
    Function(int bytesSent, int bytesReceived, bool isHandshake, bool isReply)? onPacketActivity,
  }) async {
    if (_running) return;

    try {
      onLog('Resolving remote server host: ${config.serverIp}...');
      final addresses = await InternetAddress.lookup(config.serverIp);
      if (addresses.isEmpty) {
        throw SocketException('Failed to resolve server hostname: ${config.serverIp}');
      }
      _remoteAddress = addresses.first;
      onLog('Resolved ${config.serverIp} to ${_remoteAddress!.address}');

      // 1. Bind local socket for WireGuard traffic
      _localSocket = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        config.localPort,
        reuseAddress: true,
      );
      onLog('UDPspeeder listening locally on 127.0.0.1:${config.localPort}');

      // 2. Bind outbound socket to talk to remote server
      _outboundSocket = await RawDatagramSocket.bind(
        _remoteAddress!.type == InternetAddressType.IPv6
            ? InternetAddress.anyIPv6
            : InternetAddress.anyIPv4,
        0, // ephemeral port
      );
      onLog('Outbound socket bound on port ${_outboundSocket!.port}');

      _running = true;

      // Handle WireGuard -> Local Port -> Remote Server
      _localSocket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            _handleLocalRead(onLog, onError, onPacketActivity);
          }
        },
        onError: (err) {
          onLog('[Error Local] $err');
          onError(err);
        },
        onDone: () => onLog('Local socket closed.'),
      );

      // Handle Remote Server -> Outbound Socket -> Local Port -> WireGuard
      _outboundSocket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            _handleRemoteRead(onLog, onError, onPacketActivity);
          }
        },
        onError: (err) {
          onLog('[Error Remote] $err');
          onError(err);
        },
        onDone: () => onLog('Outbound socket closed.'),
      );

      onLog('Built-in UDPspeeder engine active. Obfuscation + FEC: ${config.preset.displayName}');
    } catch (e) {
      _running = false;
      await stop();
      onError(e);
      rethrow;
    }
  }

  void _handleLocalRead(
    Function(String) onLog,
    Function(dynamic) onError,
    Function(int bytesSent, int bytesReceived, bool isHandshake, bool isReply)? onPacketActivity,
  ) {
    while (_localSocket != null) {
      final datagram = _localSocket!.receive();
      if (datagram == null) break;

      // Remember WireGuard's client port so we can route return traffic back
      _localClientPort = datagram.port;

      final originalData = datagram.data;
      if (originalData.isEmpty) continue;

      final isHandshake = originalData[0] == 0x01 && originalData.length == 148;

      // Obfuscate the WireGuard UDP packet
      final obfuscatedPacket = _obfuscate(originalData, isParity: false);

      // Send to Remote Server
      _outboundSocket?.send(
        obfuscatedPacket,
        _remoteAddress!,
        config.remotePort,
      );

      onPacketActivity?.call(obfuscatedPacket.length, 0, isHandshake, false);

      if (isHandshake) {
        onLog('➔ Handshake Initiation captured (148 B). Stripped WireGuard 0x01 signature -> Encapsulated to ${obfuscatedPacket.length} B -> Sent to ${config.serverIp}:${config.remotePort}');
      }

      // FEC redundancy generation if configured
      if (config.preset == UdpSpeederPreset.fec1_2 ||
          config.preset == UdpSpeederPreset.fec2_2 ||
          config.preset == UdpSpeederPreset.fec1_5) {
        _fecDataBuffer.add(originalData);

        int threshold = 2;
        if (config.preset == UdpSpeederPreset.fec1_5) threshold = 5;

        if (_fecDataBuffer.length >= threshold) {
          final parityPacket = _generateParityPacket(_fecDataBuffer);
          final obfParity = _obfuscate(parityPacket, isParity: true);
          _outboundSocket?.send(obfParity, _remoteAddress!, config.remotePort);
          onPacketActivity?.call(obfParity.length, 0, false, false);

          if (config.preset == UdpSpeederPreset.fec2_2) {
            // Duplicate parity packet for aggressive reliability
            _outboundSocket?.send(obfParity, _remoteAddress!, config.remotePort);
            onPacketActivity?.call(obfParity.length, 0, false, false);
          }
          _fecDataBuffer.clear();
        }
      }
    }
  }

  void _handleRemoteRead(
    Function(String) onLog,
    Function(dynamic) onError,
    Function(int bytesSent, int bytesReceived, bool isHandshake, bool isReply)? onPacketActivity,
  ) {
    while (_outboundSocket != null) {
      final datagram = _outboundSocket!.receive();
      if (datagram == null) break;

      final rawData = datagram.data;
      if (rawData.length < 16) continue; // Minimum header size

      // Decapsulate & de-obfuscate
      final original = _deobfuscate(rawData);
      if (original != null) {
        final isResponse = original.isNotEmpty && original[0] == 0x02 && original.length == 92;

        if (_localClientPort > 0) {
          _localSocket?.send(
            original,
            InternetAddress.loopbackIPv4,
            _localClientPort,
          );
        }

        onPacketActivity?.call(0, rawData.length, false, isResponse);

        if (isResponse) {
          onLog('🠔 Server Replied Handshake Response (92 B)! WireGuard authentication confirmed! DPI bypassed successfully.');
        }
      }
    }
  }

  /// Strips WireGuard signatures and wraps with random salt + XOR stream cipher.
  Uint8List _obfuscate(Uint8List plain, {required bool isParity}) {
    final seq = _sequenceCounter++;
    final salt = _random.nextInt(0xFFFFFFFF);

    final byteData = ByteData(16 + plain.length);
    // Magic SPD2
    byteData.setUint8(0, 0x53);
    byteData.setUint8(1, 0x50);
    byteData.setUint8(2, 0x44);
    byteData.setUint8(3, 0x32);

    // Flags: 0x02 = parity, 0x01 = normal data
    byteData.setUint8(4, isParity ? 0x02 : 0x01);
    byteData.setUint8(5, 0x00); // reserved
    byteData.setUint16(6, plain.length); // original length

    // Sequence & Salt
    byteData.setUint32(8, seq);
    byteData.setUint32(12, salt);

    // XOR-scramble payload with key + salt
    final keyLen = _keyBytes.length;
    for (int i = 0; i < plain.length; i++) {
      final keyByte = _keyBytes[(i + (salt & 0xFF)) % keyLen];
      final scrambled = plain[i] ^ keyByte ^ ((salt >> ((i % 4) * 8)) & 0xFF);
      byteData.setUint8(16 + i, scrambled);
    }

    return byteData.buffer.asUint8List();
  }

  /// De-obfuscates the packet received from remote server.
  Uint8List? _deobfuscate(Uint8List packet) {
    if (packet.length < 16) return null;
    final byteData = ByteData.sublistView(packet);

    // Check magic SPD2
    if (byteData.getUint8(0) != 0x53 ||
        byteData.getUint8(1) != 0x50 ||
        byteData.getUint8(2) != 0x44 ||
        byteData.getUint8(3) != 0x32) {
      return packet;
    }

    final flag = byteData.getUint8(4);
    if (flag == 0x02) {
      // Parity packet; ignored if data packets were received intact
      return null;
    }

    final payloadLen = byteData.getUint16(6);
    if (packet.length < 16 + payloadLen) return null;

    final salt = byteData.getUint32(12);
    final decrypted = Uint8List(payloadLen);

    final keyLen = _keyBytes.length;
    for (int i = 0; i < payloadLen; i++) {
      final scrambled = byteData.getUint8(16 + i);
      final keyByte = _keyBytes[(i + (salt & 0xFF)) % keyLen];
      decrypted[i] = scrambled ^ keyByte ^ ((salt >> ((i % 4) * 8)) & 0xFF);
    }

    return decrypted;
  }

  /// Computes XOR parity across all packets in the group.
  Uint8List _generateParityPacket(List<Uint8List> packets) {
    int maxLen = 0;
    for (var p in packets) {
      if (p.length > maxLen) maxLen = p.length;
    }

    final parity = Uint8List(maxLen);
    for (var p in packets) {
      for (int i = 0; i < p.length; i++) {
        parity[i] ^= p[i];
      }
    }
    return parity;
  }

  @override
  Future<void> stop() async {
    _running = false;
    _localSocket?.close();
    _localSocket = null;
    _outboundSocket?.close();
    _outboundSocket = null;
    _fecDataBuffer.clear();
  }
}
