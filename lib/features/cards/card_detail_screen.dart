import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';

import '../../data/services/security_service.dart';
import 'fullscreen_card_screen.dart';

class CardDetailScreen extends StatefulWidget {
  final Map<String, String> item;

  const CardDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  bool showPin = false;

  Future<void> revealPin() async {
    final success = await SecurityService.authenticate();

    if (!mounted) return;

    if (success) {
      setState(() => showPin = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authenticatie mislukt of geannuleerd'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name'] ?? '';
    final code = widget.item['code'] ?? '';
    final type = widget.item['type'] ?? '';
    final note = widget.item['note'] ?? '';

    final cardNumber = widget.item['cardNumber'] ?? '';
    final pinCode = widget.item['pinCode'] ?? '';
    final currentBalance = widget.item['currentBalance'] ?? '';

    final isGiftCard = type == 'Cadeaukaart';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(type),
                  const SizedBox(height: 24),
                  BarcodeWidget(
                    barcode: type == 'QR-code'
                        ? Barcode.qrCode()
                        : Barcode.code128(),
                    data: code,
                    width: double.infinity,
                    height: type == 'QR-code' ? 220 : 120,
                    drawText: type != 'QR-code',
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    code,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // 🎁 Cadeaukaart extra info
          if (isGiftCard) ...[
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (cardNumber.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.confirmation_number),
                        title: const Text('Kaartnummer'),
                        subtitle: SelectableText(cardNumber),
                      ),

                    if (currentBalance.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.euro),
                        title: const Text('Saldo'),
                        subtitle: Text('€ $currentBalance'),
                      ),

                    if (pinCode.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lock),
                        title: const Text('Pincode'),
                        subtitle: SelectableText(
                          showPin ? pinCode : '••••••',
                        ),
                        trailing: TextButton.icon(
                          onPressed: showPin ? null : revealPin,
                          icon: Icon(
                            showPin
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          label: Text(showPin ? 'Getoond' : 'Toon'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          if (note.isNotEmpty) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(note),
              ),
            ),
          ],

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FullscreenCardScreen(item: widget.item),
                ),
              );
            },
            icon: const Icon(Icons.fullscreen),
            label: const Text('Open fullscreen'),
          ),
        ],
      ),
    );
  }
}