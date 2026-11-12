import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'login_screen.dart';
import 'balance_screen.dart';

final storage = FlutterSecureStorage();

final globalWebViewController = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Pixel 7a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EdenredApp());
}

class EdenredApp extends StatelessWidget {
  const EdenredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EmberGreen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF01412F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const StartupRouter(),
    );
  }
}

/// Checks if we have a saved token, routes to balance or login accordingly.
class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final token = await storage.read(key: 'token');
    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BalanceScreen(token: token)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
