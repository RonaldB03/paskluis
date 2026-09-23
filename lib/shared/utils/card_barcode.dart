import 'package:barcode_widget/barcode_widget.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as scanner;

/// Keep the scanner's symbology; the number of digits does not identify it.
String? scannedBarcodeSymbology(scanner.BarcodeFormat? format) =>
    switch (format) {
      scanner.BarcodeFormat.ean8 => 'ean8',
      scanner.BarcodeFormat.ean13 => 'ean13',
      scanner.BarcodeFormat.code128 => 'code128',
      scanner.BarcodeFormat.code39 => 'code39',
      scanner.BarcodeFormat.code93 => 'code93',
      scanner.BarcodeFormat.codabar => 'codabar',
      scanner.BarcodeFormat.upcA => 'upca',
      scanner.BarcodeFormat.upcE => 'upce',
      scanner.BarcodeFormat.itf ||
      scanner.BarcodeFormat.itf14 ||
      scanner.BarcodeFormat.itf2of5 ||
      scanner.BarcodeFormat.itf2of5WithChecksum => 'itf',
      _ => null,
    };

bool _validEan(String code, int length) {
  if (code.length != length || !RegExp(r'^\d+$').hasMatch(code)) return false;
  var sum = 0;
  for (var i = 0; i < length - 1; i++) {
    sum += int.parse(code[i]) * (i.isEven == (length == 8) ? 3 : 1);
  }
  return (10 - sum % 10) % 10 == int.parse(code[length - 1]);
}

Barcode cardBarcode(String code, {String? symbology}) {
  switch (symbology) {
    case 'ean8':
      if (_validEan(code, 8)) return Barcode.ean8();
      return Barcode.code128();
    case 'ean13':
      if (_validEan(code, 13)) return Barcode.ean13();
      return Barcode.code128();
    case 'code39':
      return Barcode.code39();
    case 'code93':
      return Barcode.code93();
    case 'codabar':
      return Barcode.codabar();
    case 'upca':
      return Barcode.upcA();
    case 'upce':
      return Barcode.upcE();
    case 'itf':
      return Barcode.itf();
    case 'code128':
      return Barcode.code128();
  }
  // Older cards have no symbology. Only infer EAN when its check digit is valid.
  if (_validEan(code, 13)) return Barcode.ean13();
  if (_validEan(code, 8)) return Barcode.ean8();
  return Barcode.code128();
}
