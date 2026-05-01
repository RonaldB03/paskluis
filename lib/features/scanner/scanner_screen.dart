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

  bool get isQr => widget.mode == ScannerMode.qr;

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
    final frameWidth = isQr ? 280.0 : 330.0;
    final frameHeight = isQr ? 280.0 : 165.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(isQr ? 'QR-code scannen' : 'Barcode scannen'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: handleDetect,
          ),

          // Donkere overlay
          Container(
            color: Colors.black.withOpacity(0.18),
          ),

          // Scan-frame
          Center(
            child: Container(
              width: frameWidth,
              height: frameHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isQr ? 28 : 22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.95),
                  width: 3,
                ),
              ),
              child: Stack(
                children: [
                  _Corner(
                    alignment: Alignment.topLeft,
                    top: true,
                    left: true,
                  ),
                  _Corner(
                    alignment: Alignment.topRight,
                    top: true,
                    left: false,
                  ),
                  _Corner(
                    alignment: Alignment.bottomLeft,
                    top: false,
                    left: true,
                  ),
                  _Corner(
                    alignment: Alignment.bottomRight,
                    top: false,
                    left: false,
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 24,
            right: 24,
            bottom: 54,
            child: Column(
              children: [
                Text(
                  isQr
                      ? 'Richt de camera op de QR-code'
                      : 'Richt de camera op de barcode',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
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

class _Corner extends StatelessWidget {
  final Alignment alignment;
  final bool top;
  final bool left;

  const _Corner({
    required this.alignment,
    required this.top,
    required this.left,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 34,
        height: 34,
        child: CustomPaint(
          painter: _CornerPainter(
            top: top,
            left: left,
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top;
  final bool left;

  _CornerPainter({
    required this.top,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();

    if (top && left) {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}