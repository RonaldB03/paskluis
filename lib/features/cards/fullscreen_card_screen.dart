import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';

class FullscreenCardScreen extends StatefulWidget {
  final Map<String, String> item;

  const FullscreenCardScreen({
    super.key,
    required this.item,
  });

  @override
  State<FullscreenCardScreen> createState() => _FullscreenCardScreenState();
}

class _FullscreenCardScreenState extends State<FullscreenCardScreen> {
  double? _oldBrightness;

  @override
  void initState() {
    super.initState();
    _enableKassaMode();
  }

  Future<void> _enableKassaMode() async {
    try {
      _oldBrightness = await ScreenBrightness().application;
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
      await WakelockPlus.enable();
    } catch (_) {}
  }

  Future<void> _disableKassaMode() async {
    try {
      if (_oldBrightness != null) {
        await ScreenBrightness().setApplicationScreenBrightness(_oldBrightness!);
      } else {
        await ScreenBrightness().resetApplicationScreenBrightness();
      }
      await WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disableKassaMode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.item['code'] ?? '';
    final type = widget.item['type'] ?? '';
    final name = widget.item['name'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    BarcodeWidget(
                      barcode: type == 'QR-code'
                          ? Barcode.qrCode()
                          : Barcode.code128(),
                      data: code,
                      width: double.infinity,
                      height: type == 'QR-code' ? 320 : 160,
                      drawText: false,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}