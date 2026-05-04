import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
    this.showManualAfterDelay = true,
  });

  final bool showManualAfterDelay;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: [
      BarcodeFormat.qrCode,
    ],
  );

  late final AnimationController scanLineController;

  Timer? manualTimer;

  bool scanned = false;
  bool showManualButton = false;
  bool torchEnabled = false;
  bool usingFrontCamera = false;
  bool importingImage = false;

  @override
  void initState() {
    super.initState();

    scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    if (widget.showManualAfterDelay) {
      manualTimer = Timer(const Duration(seconds: 6), () {
        if (!mounted || scanned) return;
        setState(() => showManualButton = true);
      });
    } else {
      showManualButton = true;
    }
  }

  @override
  void dispose() {
    manualTimer?.cancel();
    scanLineController.dispose();
    controller.dispose();
    super.dispose();
  }

  void handleDetect(BarcodeCapture capture) {
    if (scanned) return;

    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue?.trim();

    if (value == null || value.isEmpty) return;

    finishWithCode(value);
  }

  void finishWithCode(String code) {
    if (scanned) return;

    scanned = true;
    Navigator.pop(context, code);
  }

  Future<void> toggleTorch() async {
    await controller.toggleTorch();

    if (!mounted) return;

    setState(() {
      torchEnabled = !torchEnabled;
    });
  }

  Future<void> switchCamera() async {
    await controller.switchCamera();

    if (!mounted) return;

    setState(() {
      usingFrontCamera = !usingFrontCamera;
    });
  }

  Future<void> openManualEntry() async {
    if (scanned) return;

    final code = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _ManualQrCodeDialog(),
    );

    if (code == null || code.trim().isEmpty) return;

    finishWithCode(code.trim());
  }

  Future<void> importScreenshot() async {
    if (scanned || importingImage) return;

    setState(() => importingImage = true);

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        if (mounted) setState(() => importingImage = false);
        return;
      }

      final result = await controller.analyzeImage(image.path);
      final barcode = result?.barcodes.firstOrNull;
      final value = barcode?.rawValue?.trim();

      if (value == null || value.isEmpty) {
        if (!mounted) return;

        setState(() => importingImage = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geen QR-code gevonden in deze afbeelding.'),
          ),
        );
        return;
      }

      finishWithCode(value);
    } catch (_) {
      if (!mounted) return;

      setState(() => importingImage = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Afbeelding kon niet worden gelezen.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const frameSize = 285.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: handleDetect,
          ),
          const _ScannerOverlay(
            frameWidth: frameSize,
            frameHeight: frameSize,
          ),
          Center(
            child: SizedBox(
              width: frameSize,
              height: frameSize,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.9),
                        width: 2,
                      ),
                    ),
                  ),
                  const _Corner(
                    alignment: Alignment.topLeft,
                    top: true,
                    left: true,
                  ),
                  const _Corner(
                    alignment: Alignment.topRight,
                    top: true,
                    left: false,
                  ),
                  const _Corner(
                    alignment: Alignment.bottomLeft,
                    top: false,
                    left: true,
                  ),
                  const _Corner(
                    alignment: Alignment.bottomRight,
                    top: false,
                    left: false,
                  ),
                  AnimatedBuilder(
                    animation: scanLineController,
                    builder: (_, __) {
                      return Positioned(
                        top: 20 + (scanLineController.value * (frameSize - 40)),
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD51B46),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD51B46)
                                    .withOpacity(0.65),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'QR-code scannen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  _CircleIconButton(
                    icon: torchEnabled
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    onTap: toggleTorch,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 42,
            child: Column(
              children: [
                const Text(
                  'Plaats de QR-code binnen het kader',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'De QR-code wordt automatisch herkend',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: _BottomActionButton(
                        icon: Icons.keyboard_alt_outlined,
                        label: 'Handmatig',
                        visible: showManualButton,
                        onTap: openManualEntry,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BottomActionButton(
                        icon: importingImage
                            ? Icons.hourglass_top_rounded
                            : Icons.image_outlined,
                        label: importingImage ? 'Lezen...' : 'Importeren',
                        visible: true,
                        onTap: importingImage ? null : importScreenshot,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SecondaryActionButton(
                  icon: Icons.cameraswitch_outlined,
                  label: usingFrontCamera
                      ? 'Gebruik achtercamera'
                      : 'Camera wisselen',
                  onTap: switchCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final double frameWidth;
  final double frameHeight;

  const _ScannerOverlay({
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScannerOverlayPainter(
        frameWidth: frameWidth,
        frameHeight: frameHeight,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double frameWidth;
  final double frameHeight;

  _ScannerOverlayPainter({
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.68)
      ..style = PaintingStyle.fill;

    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;

    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, frameWidth, frameHeight),
          const Radius.circular(28),
        ),
      );

    final overlayPath = Path.combine(
      PathOperation.difference,
      fullPath,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: Color(0xFFD51B46), width: 5)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: Color(0xFFD51B46), width: 5)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: Color(0xFFD51B46), width: 5)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: Color(0xFFD51B46), width: 5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.13),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool visible;
  final VoidCallback? onTap;

  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !visible,
        child: SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFD51B46),
              disabledBackgroundColor: Colors.white.withOpacity(0.75),
              disabledForegroundColor: const Color(0xFFD51B46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withOpacity(0.86),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ManualQrCodeDialog extends StatefulWidget {
  const _ManualQrCodeDialog();

  @override
  State<_ManualQrCodeDialog> createState() => _ManualQrCodeDialogState();
}

class _ManualQrCodeDialogState extends State<_ManualQrCodeDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.qr_code_2_rounded,
              color: Color(0xFFD51B46),
              size: 42,
            ),
            const SizedBox(height: 14),
            const Text(
              'QR-code handmatig invoeren',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Voer de tekst, link of code in die in de QR-code staat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black.withOpacity(0.55),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.text,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                hintText: 'Bijv. https://voorbeeld.nl/ticket',
                filled: true,
                fillColor: const Color(0xFFF4F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 17,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Annuleren',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD51B46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'Verder',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}