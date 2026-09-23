import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:paskluis_v1/data/services/card_image_signals.dart';

void main() {
  const card = Barcode(rawValue: '00012000', format: BarcodeFormat.itf2of5);
  const capture = BarcodeCapture(barcodes: [card]);

  test('keeps a successfully read barcode when OCR fails', () async {
    final result = await readCardImageSignals(
      readBarcodes: () async => capture,
      readText: () async => throw StateError('OCR unavailable'),
    );
    expect(result.barcodes, capture);
    expect(result.text, isNull);
  });

  test('keeps OCR when image barcode analysis fails', () async {
    final text = RecognizedText(text: 'Kaartnummer 00012000', blocks: []);
    final result = await readCardImageSignals(
      readBarcodes: () async => throw StateError('image decoder failed'),
      readText: () async => text,
    );
    expect(result.text, text);
  });

  test('reports failure when neither reader can read the image', () async {
    await expectLater(
      readCardImageSignals(
        readBarcodes: () async => throw StateError('image decoder failed'),
        readText: () async => throw StateError('OCR failed'),
      ),
      throwsStateError,
    );
  });

  test('selects card code ahead of empty detection and marketing QR', () {
    expect(
      selectCardBarcode([
        const Barcode(),
        const Barcode(
          rawValue: 'https://shop.example',
          format: BarcodeFormat.qrCode,
        ),
        card,
      ]),
      card,
    );
  });

  test('retains QR when it is the only usable card code', () {
    const qr = Barcode(rawValue: 'ticket-123', format: BarcodeFormat.qrCode);
    expect(selectCardBarcode([const Barcode(), qr]), qr);
  });
}
