import 'dart:convert';
import 'dart:io';
import 'package:paskluis_v1/data/services/watch_snapshot.dart';

// Synthetic cards only; consumed by verify_watch_barcodes.py and native tests.
void main() {
  final samples = <Map<String, String>>[
    {'barcodeSymbology': 'ean13', 'code': '0123456789012'},
    {'barcodeSymbology': 'ean8', 'code': '12345670'},
    {'barcodeSymbology': 'code128', 'code': '001234567890'},
    {'barcodeSymbology': 'code39', 'code': 'TEST123'},
    {'barcodeSymbology': 'code93', 'code': 'TEST123'},
    {'barcodeSymbology': 'itf', 'code': '00123456'},
    {'barcodeSymbology': 'upca', 'code': '012345678905'},
    {'barcodeSymbology': 'upce', 'code': '01234565'},
    {'codeFormat': 'qr', 'code': 'https://paskluis.nl/test'},
    {'codeFormat': 'qr', 'code': '0000123456789'},
  ];
  final fixtures = <Map<String, Object>>[];
  for (var i = 0; i < samples.length; i++) {
    fixtures.add(
      WatchSnapshot.card({
        'id': 'test-$i',
        'name': 'Test $i',
        'type': 'Pasje',
        ...samples[i],
      }),
    );
  }
  final path = File('build/watch-fixtures.json');
  path.parent.createSync(recursive: true);
  path.writeAsStringSync(jsonEncode(fixtures));
  stdout.writeln('Wrote ${fixtures.length} synthetic barcode fixtures.');
}
