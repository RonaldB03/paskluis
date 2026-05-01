import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/services/security_service.dart';

class CardDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const CardDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  bool showPin = false;
  double? oldBrightness;

  @override
  void initState() {
    super.initState();
    _prepareScreen();
  }

  Future<void> _prepareScreen() async {
    await WakelockPlus.enable();

    try {
      oldBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (_) {}
  }

  @override
  void dispose() {
    WakelockPlus.disable();

    if (oldBrightness != null) {
      ScreenBrightness().setScreenBrightness(oldBrightness!);
    }

    super.dispose();
  }

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
    final name = widget.item['name']?.toString() ?? '';
    final code = widget.item['code']?.toString() ?? '';
    final type = widget.item['type']?.toString() ?? '';
    final note = widget.item['note']?.toString() ?? '';

    final cardNumber = widget.item['cardNumber']?.toString() ?? '';
    final pinCode = widget.item['pinCode']?.toString() ?? '';
    final currentBalance = widget.item['currentBalance']?.toString() ?? '';

    final isQrCode = type == 'QR-code';
    final isGiftCard = type == 'Cadeaukaart';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(name.isEmpty ? 'Kaart' : name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const SizedBox(height: 20),

            Text(
              name.isEmpty ? 'Kaart' : name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),

            if (type.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                type,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 16,
                ),
              ),
            ],

            const SizedBox(height: 42),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black12),
              ),
              child: BarcodeWidget(
                barcode: isQrCode ? Barcode.qrCode() : Barcode.code128(),
                data: code,
                width: double.infinity,
                height: isQrCode ? 260 : 155,
                drawText: !isQrCode,
              ),
            ),

            const SizedBox(height: 20),

            SelectableText(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                letterSpacing: 1,
                color: Colors.black54,
              ),
            ),

            if (isGiftCard) ...[
              const SizedBox(height: 28),

              Card(
                elevation: 0,
                color: const Color(0xFFF5F5F7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                elevation: 0,
                color: const Color(0xFFF5F5F7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    note,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),

            const Text(
              'Houd je scherm bij de scanner',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}