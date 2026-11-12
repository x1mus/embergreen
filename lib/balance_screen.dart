import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:embergreen/main.dart';
import 'login_screen.dart';

// ─── API constants (from reverse-engineered web app) ─────────────────────────
const _apiBase       = 'https://api.be.edenred.io';
const _xClientId     = '0e86e183bf104257abb124d7cc483707';
const _xClientSecret = '1F6e9630a95d40158cc3eeB2D31c58f6';
// ─────────────────────────────────────────────────────────────────────────────

class BalanceScreen extends StatefulWidget {
  final String token;
  const BalanceScreen({super.key, required this.token});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  bool _loading = false;
  String? _error;
  List<_CardData> _cards = [];
  DateTime? _lastRefreshed;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    setState(() { _loading = true; _error = null; });

    try {
      final resp = await http.get(
        Uri.parse('$_apiBase/xp-user/v1.0/cards'),
        headers: {
          'Authorization':  'Bearer ${widget.token}',
          'X-Client-Id':     _xClientId,
          'X-Client-Secret': _xClientSecret,
          'X-Correlation-Id': 'flutter-edenred-app',
          'Accept':          'application/json',
          'Accept-Language': 'fr',
          'Origin':          'https://new.myedenred.be',
        },
      );

      if (resp.statusCode == 401) {
        // Token expired — force re-login
        await _logout(expired: true);
        return;
      }

      if (resp.statusCode != 200) {
        throw Exception('API error: ${resp.statusCode}');
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final rawCards = (json['data'] as List?) ?? [];

      setState(() {
        _cards = rawCards.map((c) => _CardData.fromJson(c)).toList();
        _lastRefreshed = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _logout({bool expired = false}) async {
    await storage.delete(key: 'token');
    if (!mounted) return;

    if (expired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expirée, veuillez vous reconnecter.')),
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('EmberGreen'),
        backgroundColor: const Color(0xFF01412F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () => _logout(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF01412F)))
          : _error != null
              ? _buildError()
              : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchBalance,
        backgroundColor: const Color(0xFF01412F),
        foregroundColor: Colors.white,
        tooltip: 'Actualiser',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFF01412F), size: 48),
            const SizedBox(height: 16),
            Text('Erreur: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchBalance,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_cards.isEmpty) {
      return const Center(child: Text('Aucune carte trouvée.'));
    }

    return RefreshIndicator(
      onRefresh: _fetchBalance,
      color: const Color(0xFF01412F),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Last refreshed timestamp
          if (_lastRefreshed != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Actualisé à ${_formatTime(_lastRefreshed!)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          // Cards
          ..._cards.map((card) => _buildCardWidget(card)),
        ],
      ),
    );
  }

  Widget _buildCardWidget(_CardData card) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.credit_card, color: Color(0xFF01412F), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    card.holderName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _StatusChip(status: card.status),
              ],
            ),
            const Divider(height: 24),

            // Wallets
            ...card.wallets.map((w) => _buildWalletRow(w)),

            const SizedBox(height: 12),

            // Footer info
            Text(
              'Expire le ${_formatDate(card.expirationDate)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletRow(_WalletData wallet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _productLabel(wallet.productRef),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '${wallet.balance} ${wallet.currency}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF01412F),
                  ),
                ),
              ],
            ),
          ),
          // Next expiring load
          if (wallet.nextExpiringAmount > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Expire le', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  _formatDate(wallet.nextExpiringDate),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${wallet.nextExpiringAmount} ${wallet.currency}',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _productLabel(String ref) {
    switch (ref) {
      case 'TRE': return 'Titre-Repas';
      case 'ECO': return 'Eco-chèque';
      case 'GIF': return 'Chèque-Cadeau';
      default:    return ref;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '?';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Status chip ──────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Actif' : status,
        style: TextStyle(
          color: isActive ? Colors.green.shade800 : Colors.red.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────
class _CardData {
  final String holderName;
  final String status;
  final DateTime? expirationDate;
  final List<_WalletData> wallets;

  _CardData({
    required this.holderName,
    required this.status,
    required this.expirationDate,
    required this.wallets,
  });

  factory _CardData.fromJson(Map<String, dynamic> j) {
    return _CardData(
      holderName:     (j['card_holder']?['full_name'] as String?) ?? 'Inconnu',
      status:         (j['status'] as String?) ?? '',
      expirationDate: _parseDate(j['expiration_date']),
      wallets: ((j['wallets'] as List?) ?? [])
          .map((w) => _WalletData.fromJson(w))
          .toList(),
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    try { return DateTime.parse(val as String); } catch (_) { return null; }
  }
}

class _WalletData {
  final String productRef;
  final String currency;
  final double balance;
  final double nextExpiringAmount;
  final DateTime? nextExpiringDate;

  _WalletData({
    required this.productRef,
    required this.currency,
    required this.balance,
    required this.nextExpiringAmount,
    required this.nextExpiringDate,
  });

  factory _WalletData.fromJson(Map<String, dynamic> j) {
    final remaining = (j['remaining'] as Map?) ?? {};
    final nxl       = (j['next_expiring_load'] as Map?) ?? {};
    return _WalletData(
      productRef:          (j['product_ref'] as String?) ?? '?',
      currency:            (j['currency'] as String?) ?? 'EUR',
      balance:             ((remaining['amount'] as num?) ?? 0) / 100,
      nextExpiringAmount:  ((nxl['amount'] as num?) ?? 0) / 100,
      nextExpiringDate:    _parseDate(nxl['expiry_date']),
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    try { return DateTime.parse(val as String); } catch (_) { return null; }
  }
}
