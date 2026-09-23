import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A barcode can succeed while OCR fails (and vice versa). Preserve either
/// successful result instead of aborting the complete gift-card import.
Future<({BarcodeCapture? barcodes, RecognizedText? text})>
readCardImageSignals({
  required Future<BarcodeCapture?> Function() readBarcodes,
  required Future<RecognizedText> Function() readText,
}) async {
  BarcodeCapture? barcodes;
  RecognizedText? text;
  Object? barcodeError;
  try {
    barcodes = await readBarcodes();
  } catch (error) {
    barcodeError = error;
  }
  try {
    text = await readText();
  } catch (error) {
    if (!((barcodes?.barcodes ?? []).any(
      (barcode) => barcode.rawValue?.trim().isNotEmpty == true,
    ))) {
      throw barcodeError ?? error;
    }
  }
  return (barcodes: barcodes, text: text);
}

/// A gift card often has a marketing QR link beside its actual card barcode.
/// Prefer a usable linear code, and skip empty observations entirely.
Barcode? selectCardBarcode(Iterable<Barcode> barcodes) {
  final readable = barcodes.where(
    (barcode) => barcode.rawValue?.trim().isNotEmpty == true,
  );
  return readable
          .where((barcode) => barcode.format != BarcodeFormat.qrCode)
          .firstOrNull ??
      readable.firstOrNull;
}
