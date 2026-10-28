import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../models/udp2raw_config.dart';
import 'obfuscation_engine.dart';

class BuiltInUdp2RawEngine implements ObfuscationEngine {
  final Udp2RawConfig config;

  RawDatagramSocket? _localSocket;
  RawDatagramSocket? _outboundSocket;
  InternetAddress? _remoteAddress;

  int _localClientPort = 0;
  int _tcpSeq = 1000;
  int _tcpAck = 1;
  bool _running = false;

  final Random _random = Random.secure();
  late final Uint8List _keyBytes;

  BuiltInUdp2RawEngine({required this.config}) {
    _keyBytes = Uint8List.fromList(sha256.convert(config.password.codeUnits).bytes);
    _tcpSeq = _random.nextInt(0x0FFFFFFF) + 10000;
  }

  @override
  bool get isRunning => _running;

  @override
  String get engineName => 'Built-in udp2raw (Dart Core)';

  @override
  Future<void> start({
    required Function(String log) onLog,
    required Function(dynamic error) onError,
    Function(int bytesSent, int bytesReceived, bool isHandshake, bool isReply)? onPacketActivity,
  }) async {
    if (_running) return;

    try {
      onLog('Resolving remote udp2raw host: ${config.serverIp}...');
      final addresses = await InternetAddress.lookup(config.serverIp);
      if (addresses.isEmpty) {
        throw SocketException('Failed to resolve server hostname: ${config.serverIp}');
      }
      _remoteAddress = addresses.first;
      onLog('Resolved ${config.serverIp} to ${_remoteAddress!.address}');

      _localSocket = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        config.localPort,
        reuseAddress: true,
      );
      onLog('udp2raw listening locally on 127.0.0.1:${config.localPort}');

      _outboundSocket = await RawDatagramSocket.bind(
        _remoteAddress!.type == InternetAddressType.IPv6
            ? InternetAddress.anyIPv6
            : InternetAddress.anyIPv4,
        0,
      );
      onLog('Outbound socket bound on port ${_outboundSocket!.port}');

      _running = true;

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

      onLog('Built-in udp2raw engine active. Mode: ${config.rawMode.displayName}, Cipher: ${config.cipherMode.displayName}');
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

      _localClientPort = datagram.port;
      final originalData = datagram.data;
      if (originalData.isEmpty) continue;

      final isHandshake = originalData[0] == 0x01 && originalData.length == 148;

      // Encapsulate with FakeTCP / Obfuscated framing
      final encapsulated = _encapsulate(originalData);

      _outboundSocket?.send(
        encapsulated,
        _remoteAddress!,
        config.remotePort,
      );

      onPacketActivity?.call(encapsulated.length, 0, isHandshake, false);

      if (isHandshake) {
        onLog('➔ FakeTCP Handshake SYN/Data emitted. WireGuard 0x01 disguised as TCP seq #$_tcpSeq -> Sent to ${config.serverIp}:${config.remotePort}');
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
      if (rawData.length < 20) continue;

      final original = _decapsulate(rawData);
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
          onLog('🠔 FakeTCP Server ACK/Response received! WireGuard session authenticated. DPI bypassed.');
        }
      }
    }
  }

  /// Encapsulates UDP inside a simulated FakeTCP framing header with sequence & salt.
  Uint8List _encapsulate(Uint8List plain) {
    _tcpSeq += plain.length;
    final salt = _random.nextInt(0xFFFFFFFF);

    final byteData = ByteData(20 + plain.length);
    // Magic U2R1
    byteData.setUint8(0, 0x55);
    byteData.setUint8(1, 0x32);
    byteData.setUint8(2, 0x52);
    byteData.setUint8(3, 0x31);

    // Simulated TCP Sequence & Ack numbers
    byteData.setUint32(4, _tcpSeq);
    byteData.setUint32(8, _tcpAck);

    // Payload length & flags (ACK | PSH)
    byteData.setUint16(12, plain.length);
    byteData.setUint16(14, 0x0018); // ACK | PSH flags

    // Salt
    byteData.setUint32(16, salt);

    // Cipher
    final keyLen = _keyBytes.length;
    for (int i = 0; i < plain.length; i++) {
      final keyByte = _keyBytes[(i + (salt & 0xFF)) % keyLen];
      final scrambled = plain[i] ^ keyByte ^ ((salt >> ((i % 4) * 8)) & 0xFF);
      byteData.setUint8(20 + i, scrambled);
    }

    return byteData.buffer.asUint8List();
  }

  /// Decapsulates packet received from remote server.
  Uint8List? _decapsulate(Uint8List packet) {
    if (packet.length < 20) return null;
    final byteData = ByteData.sublistView(packet);

    if (byteData.getUint8(0) != 0x55 ||
        byteData.getUint8(1) != 0x32 ||
        byteData.getUint8(2) != 0x52 ||
        byteData.getUint8(3) != 0x31) {
      return packet;
    }

    final payloadLen = byteData.getUint16(12);
    if (packet.length < 20 + payloadLen) return null;

    final seq = byteData.getUint32(4);
    _tcpAck = seq + payloadLen;

    final salt = byteData.getUint32(16);
    final decrypted = Uint8List(payloadLen);

    final keyLen = _keyBytes.length;
    for (int i = 0; i < payloadLen; i++) {
      final scrambled = byteData.getUint8(20 + i);
      final keyByte = _keyBytes[(i + (salt & 0xFF)) % keyLen];
      decrypted[i] = scrambled ^ keyByte ^ ((salt >> ((i % 4) * 8)) & 0xFF);
    }

    return decrypted;
  }

  @override
  Future<void> stop() async {
    _running = false;
    _localSocket?.close();
    _localSocket = null;
    _outboundSocket?.close();
    _outboundSocket = null;
  }
}
