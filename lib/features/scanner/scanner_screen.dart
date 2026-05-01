import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scannen'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: handleDetect,
          ),
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
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 78,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 50,
            child: Column(
              children: [
                const Text(
                  'Richt de camera op de barcode of QR-code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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