import 'dart:convert';

import 'package:barcode/barcode.dart';

import 'card_access_policy.dart';

/// Versioned, bounded, full replacements. Never serialize the source card map.
abstract final class WatchSnapshot {
  static const maxBytes = 7000;

  static String category(Map card) => switch (card['type']) {
    'QR-code' => 'qr',
    'Cadeaukaart' => 'gift',
    _ => 'loyalty',
  };

  static bool eligible(Map card) =>
      const {'Pasje', 'QR-code', 'Cadeaukaart'}.contains(card['type']) &&
      !CardAccessPolicy.isReceived(card) &&
      card['isArchived'] != true &&
      card['isArchived'] != 'true' &&
      (card['id']?.toString().isNotEmpty ?? false) &&
      (card['code']?.toString().isNotEmpty ?? false);

  static Map<String, Object> card(Map source) {
    if (!eligible(source)) throw const FormatException('ineligible');
    final value = source['code'].toString();
    if (value.length > 256) throw const FormatException('code_too_long');
    // Older standalone QR cards identify their format through type.
    final qr = source['type'] == 'QR-code' || source['codeFormat'] == 'qr';
    final symbology = source['barcodeSymbology']?.toString();
    if (!qr &&
        symbology != null &&
        symbology.isNotEmpty &&
        !const {
          'ean8',
          'ean13',
          'code128',
          'code39',
          'code93',
          'codabar',
          'upca',
          'upce',
          'itf',
        }.contains(symbology)) {
      throw const FormatException('unsupported');
    }
    final barcode = qr
        ? Barcode.qrCode()
        : switch (symbology) {
            'ean8' => Barcode.ean8(),
            'ean13' => Barcode.ean13(),
            'code39' => Barcode.code39(),
            'code93' => Barcode.code93(),
            'codabar' => Barcode.codabar(),
            'upca' => Barcode.upcA(),
            'upce' => Barcode.upcE(),
            'itf' => Barcode.itf(),
            'code128' => Barcode.code128(),
            _ => _legacyBarcode(value),
          };
    try {
      barcode.verify(value);
    } on BarcodeException {
      throw const FormatException('invalid_code');
    }
    final bars = barcode
        .make(value, width: 1, height: 1, drawText: false)
        .whereType<BarcodeBar>()
        .where((bar) => bar.black)
        .toList();
    // Recover the exact integer module grid from the public vector API.
    // Do not resize/interpolate a bitmap or change the barcode symbology.
    bool integral(double value) => (value - value.round()).abs() < 0.00001;
    var width = 0;
    for (var n = 1; n <= (qr ? 49 : 211); n++) {
      if (bars.isNotEmpty &&
          bars.every(
            (b) =>
                integral(b.left * n) &&
                integral(b.width * n) &&
                (!qr || (integral(b.top * n) && integral(b.height * n))),
          )) {
        width = n;
        break;
      }
    }
    if (width == 0) throw const FormatException('too_wide');
    final height = qr ? width : 1;
    final pixels = List<bool>.filled(width * height, false);
    for (final b in bars) {
      final top = qr ? (b.top * height).round() : 0;
      final bottom = qr ? ((b.top + b.height) * height).round() : 1;
      for (var y = top; y < bottom; y++) {
        for (
          var x = (b.left * width).round();
          x < ((b.left + b.width) * width).round();
          x++
        ) {
          pixels[y * width + x] = true;
        }
      }
    }
    final hex = StringBuffer();
    for (var i = 0; i < pixels.length; i += 4) {
      var nibble = 0;
      for (var j = 0; j < 4; j++) {
        if (i + j < pixels.length && pixels[i + j]) nibble |= 1 << (3 - j);
      }
      hex.write(nibble.toRadixString(16));
    }
    final name = source['name']?.toString() ?? 'PasKluis';
    return {
      'id': source['id'].toString(),
      'name': String.fromCharCodes(name.runes.take(40)),
      'code': value,
      'favorite': source['isFavorite'] == true,
      'category': category(source),
      'width': width,
      'height': height,
      'bits': hex.toString(),
    };
  }

  static Barcode _legacyBarcode(String value) {
    // Match the existing phone's legacy fallback, only without a stored format.
    if (RegExp(r'^\d{13}$').hasMatch(value) && Barcode.ean13().isValid(value)) {
      return Barcode.ean13();
    }
    if (RegExp(r'^\d{8}$').hasMatch(value) && Barcode.ean8().isValid(value)) {
      return Barcode.ean8();
    }
    return Barcode.code128();
  }

  static Map<String, Object> build({
    required Iterable<Map> cards,
    required Set<String> selected,
    required String owner,
    required int revision,
    required String language,
  }) {
    final result = <Map<String, Object>>[];
    final seen = <String>{};
    for (final source in cards) {
      final id = source['id']?.toString() ?? '';
      if (!selected.contains(id) || !eligible(source) || !seen.add(id)) {
        continue;
      }
      try {
        result.add(card(source));
      } on FormatException catch (error) {
        // Identify the rejected card without including its code in diagnostics.
        throw FormatException(error.message, source['name']?.toString());
      }
    }
    result.sort((a, b) {
      if (a['favorite'] != b['favorite']) return a['favorite'] == true ? -1 : 1;
      return (a['name'] as String).compareTo(b['name'] as String);
    });
    final snapshot = <String, Object>{
      'schema': 1,
      'owner': owner,
      'revision': revision,
      'language': language,
      'cards': result,
    };
    if (utf8.encode(jsonEncode(snapshot)).length > maxBytes) {
      throw const FormatException('too_large');
    }
    return snapshot;
  }
}
