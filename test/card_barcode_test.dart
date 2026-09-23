import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as scanner;
import 'package:paskluis_v1/shared/utils/card_barcode.dart';

void main() {
  test(
    'an eight-digit card number with an invalid EAN check digit is rendered',
    () {
      final barcode = cardBarcode('00012000');
      expect(barcode.name, cardBarcode('ABC').name);
      expect(barcode.isValid('00012000'), isTrue);
    },
  );

  test('scanned ITF remains ITF rather than being inferred as EAN-8', () {
    final format = scannedBarcodeSymbology(
      scanner.BarcodeFormat.fromRawValue(126),
    );
    final barcode = cardBarcode('00012000', symbology: format);
    expect(format, 'itf');
    expect(barcode.isValid('00012000'), isTrue);
    expect(barcode.name, isNot(cardBarcode('ABC').name));
  });

  test('Android ITF and Apple ITF-14 keep a supported format', () {
    expect(
      scannedBarcodeSymbology(scanner.BarcodeFormat.fromRawValue(128)),
      'itf',
    );
  });

  test('valid existing EAN cards keep their barcode format', () {
    expect(cardBarcode('96385074').name, contains('EAN'));
    expect(cardBarcode('4006381333931').name, contains('EAN'));
    expect(cardBarcode('96385074').isValid('96385074'), isTrue);
  });
}
