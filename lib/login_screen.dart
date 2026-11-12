import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'balance_screen.dart';
import 'package:embergreen/main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final WebViewController _controller = globalWebViewController;
  bool _loading = true;
  bool _firstLaunch = false;

  static const _loginUrl     = 'https://new.myedenred.be/login?lng=fr';
  static const _postLoginUrl = 'https://new.myedenred.be/';

  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final email = await storage.read(key: 'email');
    if (email == null) {
      setState(() => _firstLaunch = true);
    } else {
      _emailController.text = email;
      final password = await storage.read(key: 'password') ?? '';
      _passwordController.text = password;
      _startWebView(email, password);
    }
  }

  void _startWebView(String email, String password) {
    _controller
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (url) async {
            setState(() => _loading = false);
            if (url.contains('session/step/password')) {
              await _autofillCredentials(email, password);
            }
            if (url.startsWith(_postLoginUrl)) {
              await _extractToken();
            }
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(_loginUrl));
  }

  Future<void> _saveAndStart() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    await storage.write(key: 'email', value: email);
    await storage.write(key: 'password', value: password);

    setState(() => _firstLaunch = false);
    _startWebView(email, password);
  }

  Future<void> _autofillCredentials(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _controller.runJavaScript('''
      document.getElementById('Username').value = '${email.replaceAll("'", "\\'")}';
      document.getElementById('Password').value = '${password.replaceAll("'", "\\'")}';
      document.getElementById('login').click();
    ''');
  }

  Future<void> _extractToken() async {
    String token = '';

    try {
      final result = await _controller.runJavaScriptReturningResult(
        '''document.cookie''',
      );
      final cookies = result.toString().replaceAll('"', '');
      final match = RegExp(r'TokenAuth=([^;]+)').firstMatch(cookies);
      if (match != null) {
        token = Uri.decodeComponent(match.group(1)!.trim());
      }
    } catch (e) {
      debugPrint('[!] Cookie read error: $e');
    }

    if (token.isEmpty) {
      debugPrint('[!] TokenAuth not found yet...');
      return;
    }

    await storage.write(key: 'token', value: token);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BalanceScreen(token: token)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

    @override
  Widget build(BuildContext context) {
    if (_firstLaunch) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('EmberGreen — Connexion'),
          backgroundColor: const Color(0xFF01412F),
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Entrez vos identifiants',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveAndStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF01412F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Se connecter', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion MyEdenred'),
        backgroundColor: const Color(0xFF01412F),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF01412F)),
            ),
        ],
      ),
    );
  }
}