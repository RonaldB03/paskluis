import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/l10n.dart';

/// mobile_scanner only observes lifecycle changes for its internally-created
/// controller. PasKluis supplies a controller for torch, camera and import.
class ScannerCamera extends StatefulWidget {
  const ScannerCamera({
    super.key,
    required this.controller,
    required this.onDetect,
    this.paused = false,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool paused;

  @override
  State<ScannerCamera> createState() => _ScannerCameraState();
}

class _ScannerCameraState extends State<ScannerCamera>
    with WidgetsBindingObserver {
  Future<void> _pending = Future.value();
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant ScannerCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) _syncCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // A permission prompt interrupts the initial start. Let that start finish.
    if (widget.controller.value.isStarting) return;
    if (!_foreground && !widget.controller.value.hasCameraPermission) return;
    _syncCamera();
  }

  void _syncCamera() {
    _pending = _pending.then((_) async {
      if (!mounted) return;
      try {
        if (_foreground && !widget.paused) {
          if (!widget.controller.value.isStarting) {
            await widget.controller.start();
          }
        } else {
          await widget.controller.stop();
        }
      } on MobileScannerException {
        // The controller exposes camera/permission errors to errorBuilder.
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: widget.controller,
    useAppLifecycleState: false,
    tapToFocus: true,
    onDetect: (capture) {
      if (!widget.paused && _foreground) widget.onDetect(capture);
    },
    errorBuilder: (context, error) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? L10n.current.scannerCameraPermission
                  : L10n.current.scannerCameraUnavailable,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            TextButton(
              onPressed: _syncCamera,
              child: Text(L10n.current.tryAgain),
            ),
          ],
        ),
      ),
    ),
  );
}
