import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Support the developer (v2.29, his numbers): Dhunn stays free
/// for everyone; anyone who wants to chip in can send to the
/// developer's own JazzCash / NayaPay / Easypaisa number or via
/// Binance Pay. Every detail has a copy button so nothing is
/// typed wrong. (DPay was removed on his order, 2026-11-05.)
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  void _copy(BuildContext c, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(c)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Support Dhunn')),
      body: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Column(children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: cs.primary.withOpacity(.15),
              child: Icon(Icons.favorite, color: cs.primary, size: 30),
            ),
            const SizedBox(height: 12),
            const Text('Dhunn is free — and stays free',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text(
                'No subscriptions, no locked features. If Dhunn makes your day a little better and you would like to support its development, send any amount to one of these — completely optional, always appreciated.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ]),
        ),
        _wallet(context,
            brand: 'JazzCash',
            color: const Color(0xFFED1C24),
            number: '03287331958',
            name: 'Hamza Shafique',
            hint:
                'Open JazzCash → Send Money → enter the number, check the name (Hamza Shafique) and send.'),
        _wallet(context,
            brand: 'NayaPay',
            color: const Color(0xFFFF7A18),
            number: '03287331958',
            name: 'Hamza Shafiq',
            hint:
                'Open NayaPay → Send → enter the number, check the name (Hamza Shafiq) and send.'),
        _wallet(context,
            brand: 'Easypaisa',
            color: const Color(0xFF00A651),
            number: '03287331958',
            name: 'Hamza Shafique',
            hint:
                'Open Easypaisa → Send Money → enter the number, check the name (Hamza Shafique) and send.'),
        _head('Binance Pay'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFF0B90B).withOpacity(.18),
                child: const Icon(Icons.currency_bitcoin,
                    color: Color(0xFFF0B90B), size: 20),
              ),
              title: const Text('Binance Pay ID'),
              subtitle: const Text('774780411',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy Binance Pay ID',
                onPressed: () => _copy(context, 'Binance Pay ID', '774780411'),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Name'),
              subtitle: const Text('Hamzaeditz',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy name',
                onPressed: () => _copy(context, 'Name', 'Hamzaeditz'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Text(
                  'In the Binance app: Pay → Send → enter the Pay ID above, type any amount, confirm the name (Hamzaeditz) and send.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Text(
              'Thank you for keeping Dhunn alive. — Hamza Shafiq',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey)),
        ),
      ]),
    );
  }

  Widget _head(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      );

  /// One local wallet: brand head + a card with the number and
  /// the account title, each copyable, plus a one-line how-to.
  Widget _wallet(BuildContext context,
      {required String brand,
      required Color color,
      required String number,
      required String name,
      required String hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _head(brand),
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(.16),
              child: Icon(Icons.phone_android, color: color, size: 20),
            ),
            title: const Text('Number'),
            subtitle: Text(number,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy number',
              onPressed: () => _copy(context, '$brand number', number),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Account title'),
            subtitle: Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy name',
              onPressed: () => _copy(context, 'Account title', name),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Text(hint,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ]),
      ),
    ]);
  }
}
