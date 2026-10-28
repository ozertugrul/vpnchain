import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/vpn_manager.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive dark status bar and navigation bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bgDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final vpnManager = VpnManager();
  await vpnManager.initialize();

  runApp(VpnChainApp(vpnManager: vpnManager));
}

class VpnChainApp extends StatelessWidget {
  final VpnManager vpnManager;

  const VpnChainApp({super.key, required this.vpnManager});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPNChain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeScreen(vpnManager: vpnManager),
    );
  }
}
