import 'dart:io';
import 'dart:ui' as ui;

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

/// Still images do not own a camera controller. Disposing a temporary
/// controller also disposes the shared native camera, including other routes.
abstract final class BarcodeImageService {
  static const cardFormats = [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.code93,
    BarcodeFormat.codabar,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.itf2of5,
    BarcodeFormat.itf14,
    BarcodeFormat.qrCode,
  ];
  static Future<BarcodeCapture?> analyze(
    String path, {
    List<BarcodeFormat> formats = const [],
  }) async {
    Object? firstError;
    try {
      final result = await MobileScannerPlatform.instance.analyzeImage(
        path,
        formats: formats,
      );
      if (result?.barcodes.any((b) => b.rawValue?.isNotEmpty == true) == true) {
        return result;
      }
    } catch (error) {
      firstError = error;
    }

    // Apple Vision's analyzeImage path treats the file as upright. Decode and
    // re-encode a PNG so EXIF orientation and unusual photo encodings are baked
    // into the pixels. Keep the original file untouched.
    ui.Codec? codec;
    ui.Image? image;
    Directory? temporaryDirectory;
    try {
      codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
      image = (await codec.getNextFrame()).image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      temporaryDirectory = await (await getTemporaryDirectory()).createTemp(
        'paskluis-scan-',
      );
      final file = File('${temporaryDirectory.path}/image.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      return await MobileScannerPlatform.instance.analyzeImage(
        file.path,
        formats: formats,
      );
    } catch (error) {
      throw firstError ?? error;
    } finally {
      image?.dispose();
      codec?.dispose();
      if (temporaryDirectory != null) {
        try {
          await temporaryDirectory.delete(recursive: true);
        } on FileSystemException {
          // Temporary-file cleanup must not hide a successfully decoded code.
        }
      }
    }
  }
}
