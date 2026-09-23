import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:paskluis_v1/data/services/barcode_image_service.dart';
import 'package:paskluis_v1/shared/widgets/scanner_camera.dart';

void main() {
  testWidgets('photo retry bakes EXIF rotation and removes its temporary copy', (tester) async {
    final previous = MobileScannerPlatform.instance;
    final platform = _ScannerPlatform()..retryImage = true;
    MobileScannerPlatform.instance = platform;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    final directory = Directory.systemTemp.createTempSync('paskluis-test-');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths,
        (_) async => directory.path);
    try {
      final capture = await tester.runAsync(() => BarcodeImageService.analyze(
        'test/fixtures/rotated_scan.jpg',
        formats: const [BarcodeFormat.qrCode],
      ));
      expect(capture?.barcodes.single.rawValue, 'ticket-123');
      expect(platform.normalizedSize, const Size(4, 8));
      expect(File(platform.normalizedPath!).existsSync(), isFalse);
      expect(platform.disposed, isFalse);
    } finally {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
      await platform.dispose();
      MobileScannerPlatform.instance = previous;
      directory.deleteSync(recursive: true);
    }
  });

  testWidgets('camera resumes after background and photo import cancellation', (
    tester,
  ) async {
    final previous = MobileScannerPlatform.instance;
    final platform = _ScannerPlatform();
    MobileScannerPlatform.instance = platform;
    final controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
    var paused = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ScannerCamera(
              controller: controller,
              onDetect: (_) {},
              paused: paused,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.value.isRunning, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(controller.value.isRunning, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(controller.value.isRunning, isTrue);

    rebuild(() => paused = true);
    await tester.pumpAndSettle();
    expect(controller.value.isRunning, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(controller.value.isRunning, isFalse);
    rebuild(() => paused = false);
    await tester.pumpAndSettle();
    expect(controller.value.isRunning, isTrue);

    await BarcodeImageService.analyze(
      'qr.png',
      formats: const [BarcodeFormat.qrCode],
    );
    expect(platform.imageFormats, [BarcodeFormat.qrCode]);
    expect(platform.disposed, isFalse);
    expect(controller.value.isRunning, isTrue);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
    MobileScannerPlatform.instance = previous;
  });
}

class _ScannerPlatform extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture>.broadcast();
  bool disposed = false;
  bool retryImage = false;
  int imageCalls = 0;
  Size? normalizedSize;
  String? normalizedPath;
  List<BarcodeFormat>? imageFormats;

  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.unavailable,
        size: Size(200, 200),
        numberOfCameras: 1,
      );
  @override
  Widget buildCameraView() => const SizedBox();
  @override
  Future<void> stop() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const [],
  }) async {
    imageFormats = formats;
    imageCalls++;
    if (retryImage && imageCalls == 1) return const BarcodeCapture();
    if (retryImage) {
      final bytes = ByteData.sublistView(await File(path).readAsBytes());
      normalizedPath = path;
      normalizedSize = Size(bytes.getUint32(16).toDouble(), bytes.getUint32(20).toDouble());
    }
    return const BarcodeCapture(
      barcodes: [Barcode(rawValue: 'ticket-123', format: BarcodeFormat.qrCode)],
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await captures.close();
  }
}
