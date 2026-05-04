import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class MultiQrScannerScreen extends StatefulWidget {
  const MultiQrScannerScreen({super.key});

  @override
  State<MultiQrScannerScreen> createState() => _MultiQrScannerScreenState();
}

class _MultiQrScannerScreenState extends State<MultiQrScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  final List<String> scannedCodes = [];

  bool torchEnabled = false;
  bool usingFrontCamera = false;

  late final AnimationController scanLineController;

  @override
  void initState() {
    super.initState();

    scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    scanLineController.dispose();
    controller.dispose();
    super.dispose();
  }

  void handleDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue?.trim();

    if (value == null || value.isEmpty) return;

    if (scannedCodes.contains(value)) return;

    HapticFeedback.mediumImpact();

    setState(() {
      scannedCodes.add(value);
    });
  }

  Future<void> toggleTorch() async {
    await controller.toggleTorch();

    setState(() {
      torchEnabled = !torchEnabled;
    });
  }

  Future<void> switchCamera() async {
    await controller.switchCamera();

    setState(() {
      usingFrontCamera = !usingFrontCamera;
    });
  }

  void finish() {
    if (scannedCodes.isEmpty) {
      Navigator.pop(context);
      return;
    }

    Navigator.pop(context, scannedCodes);
  }

  @override
  Widget build(BuildContext context) {
    const frameWidth = 280.0;
    const frameHeight = 280.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: handleDetect,
          ),

          // Overlay
          Center(
            child: SizedBox(
              width: frameWidth,
              height: frameHeight,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),

                  AnimatedBuilder(
                    animation: scanLineController,
                    builder: (_, __) {
                      return Positioned(
                        top: scanLineController.value * (frameHeight - 4),
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          color: const Color(0xFFD51B46),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'Meerdere QR scannen',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  _CircleButton(
                    icon: torchEnabled
                        ? Icons.flash_on
                        : Icons.flash_off,
                    onTap: toggleTorch,
                  ),
                ],
              ),
            ),
          ),

          // Bottom UI
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Column(
              children: [
                Text(
                  '${scannedCodes.length} QR-codes toegevoegd',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: finish,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD51B46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Gereed',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                TextButton.icon(
                  onPressed: switchCamera,
                  icon: const Icon(Icons.cameraswitch),
                  label: Text(
                    usingFrontCamera
                        ? 'Gebruik achtercamera'
                        : 'Camera wisselen',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
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

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.2),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}