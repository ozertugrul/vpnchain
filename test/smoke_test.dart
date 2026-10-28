import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnchain/models/tunnel_mode.dart';
import 'package:vpnchain/models/udpspeeder_config.dart';
import 'package:vpnchain/models/udp2raw_config.dart';
import 'package:vpnchain/models/vpn_profile.dart';
import 'package:vpnchain/models/vpn_stats.dart';
import 'package:vpnchain/models/wireguard_config.dart';
import 'package:vpnchain/models/log_entry.dart';
import 'package:vpnchain/services/tunnel/tunnel_orchestrator.dart';
import 'package:vpnchain/services/vpn_manager.dart';
import 'package:vpnchain/ui/screens/vps_setup_screen.dart';
import 'package:vpnchain/ui/screens/settings_screen.dart';
import 'package:vpnchain/ui/widgets/live_logs_sheet.dart';
import 'package:vpnchain/ui/widgets/mode_selector_chips.dart';
import 'package:vpnchain/ui/widgets/power_button_ring.dart';
import 'package:vpnchain/ui/widgets/stats_dashboard_card.dart';
import 'package:vpnchain/ui/widgets/udpspeeder_settings_card.dart';
import 'package:vpnchain/ui/widgets/udp2raw_settings_card.dart';
import 'package:vpnchain/ui/widgets/wireguard_config_box.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vpnchain/ui/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Widget wrapWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    );
  }

  group('Widget Smoke Tests', () {
    testWidgets('PowerButtonRing renders and triggers callback on tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        wrapWidget(
          PowerButtonRing(
            status: VpnStatus.disconnected,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('DISCONNECTED'), findsOneWidget);
      expect(find.text('Tap to Connect'), findsOneWidget);

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      expect(tapped, isTrue);

      // Connected state
      await tester.pumpWidget(
        wrapWidget(
          PowerButtonRing(
            status: VpnStatus.connected,
            onTap: () {},
          ),
        ),
      );
      expect(find.text('PROTECTED'), findsOneWidget);
      expect(find.text('Tap to Disconnect'), findsOneWidget);
    });

    testWidgets('ModeSelectorChips switches modes correctly', (tester) async {
      TunnelMode currentMode = TunnelMode.udpspeeder;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return wrapWidget(
              ModeSelectorChips(
                selectedMode: currentMode,
                onModeChanged: (m) => setState(() => currentMode = m),
              ),
            );
          },
        ),
      );

      expect(find.text('UDPspeeder'), findsOneWidget);
      expect(find.text('udp2raw'), findsOneWidget);
      expect(find.text('Direct'), findsOneWidget);

      // Tap udp2raw
      await tester.tap(find.text('udp2raw'));
      await tester.pumpAndSettle();
      expect(currentMode, TunnelMode.udp2raw);

      // Tap Direct
      await tester.tap(find.text('Direct'));
      await tester.pumpAndSettle();
      expect(currentMode, TunnelMode.direct);
    });

    testWidgets('StatsDashboardCard renders stats and triggers test ping', (tester) async {
      bool pingTested = false;
      const stats = VpnStats(
        status: VpnStatus.connected,
        downloadSpeed: 1024 * 1024 * 2, // 2 MB/s
        uploadSpeed: 512 * 1024, // 512 KB/s
        totalDownload: 1024 * 1024 * 50,
        totalUpload: 1024 * 1024 * 10,
        pingMs: 38,
        uptimeSeconds: 125,
        txPackets: 450,
        rxPackets: 890,
        handshakeStatus: HandshakeStatus.confirmed,
      );

      await tester.pumpWidget(
        wrapWidget(
          StatsDashboardCard(
            stats: stats,
            onTestPing: () => pingTested = true,
          ),
        ),
      );

      expect(find.text('PROTECTED • HANDSHAKE OK'), findsOneWidget);
      expect(find.text('38 ms'), findsOneWidget);
      expect(find.text('Test Server & Ping'), findsOneWidget);

      await tester.tap(find.text('Test Server & Ping'));
      await tester.pump();
      expect(pingTested, isTrue);
    });

    testWidgets('WireGuardConfigBox parses and edits text', (tester) async {
      String changedText = '';
      const initial = WireGuardConfig(
        rawConfig: '[Interface]\nPrivateKey = aaa\nAddress = 10.0.0.2\n[Peer]\nPublicKey = bbb\nEndpoint = 198.51.100.1:51820',
        privateKey: 'aaa',
        address: '10.0.0.2',
        peerPublicKey: 'bbb',
        endpoint: '198.51.100.1:51820',
      );

      await tester.pumpWidget(
        wrapWidget(
          WireGuardConfigBox(
            config: initial,
            onConfigChanged: (val) => changedText = val,
          ),
        ),
      );

      expect(find.text('WireGuard Configuration'), findsOneWidget);
      expect(find.text('VALID'), findsOneWidget);
      expect(find.text('Endpoint: 198.51.100.1:51820'), findsOneWidget);

      // Enter new text
      await tester.enterText(find.byType(TextField), 'new config text');
      expect(changedText, 'new config text');
    });

    testWidgets('UdpSpeederSettingsCard allows editing and preset changes', (tester) async {
      UdpSpeederConfig config = const UdpSpeederConfig(
        serverIp: '1.2.3.4',
        remotePort: 4096,
        localPort: 1234,
      );

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return wrapWidget(
              UdpSpeederSettingsCard(
                config: config,
                onChanged: (c) => setState(() => config = c),
              ),
            );
          },
        ),
      );

      expect(find.text('UDPspeeder Settings'), findsOneWidget);
      expect(find.text('1.2.3.4'), findsOneWidget);

      // Open advanced parameters
      await tester.tap(find.text('Advanced Parameters'));
      await tester.pumpAndSettle();
      expect(find.text('Hide Advanced'), findsOneWidget);
    });

    testWidgets('Udp2RawSettingsCard allows editing raw mode and options', (tester) async {
      Udp2RawConfig config = const Udp2RawConfig(
        serverIp: '1.2.3.4',
        remotePort: 4097,
        localPort: 1234,
        rawMode: RawMode.faketcp,
      );

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return wrapWidget(
              Udp2RawSettingsCard(
                config: config,
                onChanged: (c) => setState(() => config = c),
              ),
            );
          },
        ),
      );

      expect(find.text('udp2raw Settings'), findsOneWidget);
      expect(find.text('FakeTCP & DPI EVASION'), findsOneWidget);
    });

    testWidgets('LiveLogsSheet filters and displays logs', (tester) async {
      final logs = [
        LogEntry(timestamp: DateTime.now(), tag: '[WireGuard]', message: 'Interface up'),
        LogEntry(timestamp: DateTime.now(), tag: '[Tunnel]', message: 'UDPspeeder bound on port 1234'),
        LogEntry(timestamp: DateTime.now(), tag: '[System]', message: 'Connected'),
      ];

      await tester.pumpWidget(
        wrapWidget(
          LiveLogsSheet(
            logs: logs,
            onClear: () {},
          ),
        ),
      );

      expect(find.text('Live Tunnel Console'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Interface up')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('UDPspeeder bound')),
        findsOneWidget,
      );

      // Test filter
      await tester.enterText(find.byType(TextField), 'UDPspeeder');
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('UDPspeeder bound')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Interface up')),
        findsNothing,
      );
    });

    testWidgets('VpsSetupScreen renders Docker and Bash tabs', (tester) async {
      final profile = VpnProfile(
        name: 'Test Server',
        wireGuardConfig: const WireGuardConfig(rawConfig: ''),
      );

      await tester.pumpWidget(
        wrapWidget(
          VpsSetupScreen(profile: profile),
        ),
      );

      expect(find.text('Server Deployment'), findsOneWidget);
      expect(find.text('Docker Compose'), findsOneWidget);
      expect(find.text('Bash Script'), findsOneWidget);
      expect(find.text('docker-compose.yml'), findsOneWidget);

      // Switch to Bash tab
      await tester.tap(find.text('Bash Script'));
      await tester.pumpAndSettle();
      expect(find.text('setup-vpnchain.sh'), findsOneWidget);
    });

    testWidgets('SettingsScreen allows engine preference selection', (tester) async {
      final vpnManager = VpnManager();
      await vpnManager.initialize();

      await tester.pumpWidget(
        wrapWidget(
          SettingsScreen(vpnManager: vpnManager),
        ),
      );

      expect(find.text('Settings & Info'), findsOneWidget);
      expect(find.text('Auto (Recommended)'), findsOneWidget);
      expect(find.text('Built-in Dart Core Engine'), findsOneWidget);
      expect(find.text('Native CLI Process'), findsOneWidget);

      // Tap Built-in Dart Core
      await tester.tap(find.text('Built-in Dart Core Engine'));
      await tester.pump();
      expect(vpnManager.enginePreference, EnginePreference.builtin);

      vpnManager.dispose();
    });
  });
}
