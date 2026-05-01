import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum ScannerMode {
  barcode,
  qr,
}

class ScannerScreen extends StatefulWidget {
  final ScannerMode mode;

  const ScannerScreen({
    super.key,
    required this.mode,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool scanned = false;

  void handleDetect(BarcodeCapture capture) {
    if (scanned) return;

    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue;

    if (value == null || value.isEmpty) return;

    scanned = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final isQR = widget.mode == ScannerMode.qr;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(isQR ? 'QR-code scannen' : 'Barcode scannen'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: handleDetect,
          ),

          /// SCAN FRAME + ICON
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
              ),
              child: Center(
                child: Icon(
                  isQR
                      ? Icons.qr_code_scanner_rounded
                      : Icons.view_week_rounded, // 👈 barcode look
                  color: Colors.white,
                  size: 80,
                ),
              ),
            ),
          ),

          /// ONDERTEKST
          Positioned(
            left: 24,
            right: 24,
            bottom: 50,
            child: Column(
              children: [
                Text(
                  isQR
                      ? 'Richt de camera op de QR-code'
                      : 'Richt de camera op de barcode',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Annuleren'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}