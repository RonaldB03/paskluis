import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mobile;

import '../templates/card_templates.dart';
import 'brand_catalog_service.dart';

class SmartCardImportResult {
  final String type;
  final String name;
  final String code;
  final String pinCode;
  final String balance;
  final CardBrandTemplate? brand;

  const SmartCardImportResult({
    required this.type,
    required this.name,
    required this.code,
    required this.pinCode,
    required this.balance,
    this.brand,
  });
}

abstract final class SmartCardImportService {
  static Future<SmartCardImportResult?> pickAndAnalyze() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    final scanner = mobile.MobileScannerController(
      formats: const [
        mobile.BarcodeFormat.ean13,
        mobile.BarcodeFormat.ean8,
        mobile.BarcodeFormat.code128,
        mobile.BarcodeFormat.code39,
        mobile.BarcodeFormat.code93,
        mobile.BarcodeFormat.codabar,
        mobile.BarcodeFormat.upcA,
        mobile.BarcodeFormat.upcE,
        mobile.BarcodeFormat.itf,
        mobile.BarcodeFormat.qrCode,
      ],
    );
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final capture = await scanner.analyzeImage(image.path);
      final scanned = capture?.barcodes.firstOrNull;
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(image.path),
      );
      final text = recognized.text.trim();
      final normalized = _normalize(text);
      final brands = await BrandCatalogService.load();
      final brand = _findBrand(brands, normalized);
      final code = scanned?.rawValue?.trim().isNotEmpty == true
          ? scanned!.rawValue!.trim()
          : _findCardNumber(text);
      final isQr = scanned?.format == mobile.BarcodeFormat.qrCode;
      final giftWords = RegExp(
        r'cadeau|gift\s?card|tegoed|saldo|balance|pin\s?code|krascode',
        caseSensitive: false,
      ).hasMatch(text);
      final type = isQr ? 'QR-code' : giftWords ? 'Cadeaukaart' : 'Pasje';

      return SmartCardImportResult(
        type: type,
        name: brand?.name ?? _suggestName(text, type),
        code: code,
        pinCode: _findPin(text),
        balance: _findBalance(text),
        brand: brand,
      );
    } finally {
      recognizer.close();
      await scanner.dispose();
    }
  }

  static CardBrandTemplate? _findBrand(
    List<CardBrandTemplate> brands,
    String text,
  ) {
    for (final brand in brands) {
      final candidates = [brand.name, brand.id]
          .map(_normalize)
          .where((value) => value.length >= 3);
      if (candidates.any(text.contains)) return brand;
    }
    return null;
  }

  static String _findCardNumber(String text) {
    final matches = RegExp(r'(?<!\d)(?:\d[ -]?){8,24}(?!\d)')
        .allMatches(text)
        .map((match) => match.group(0)!.replaceAll(RegExp(r'\D'), ''))
        .where((value) => value.length >= 8 && value.length <= 24)
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return matches.isEmpty ? '' : matches.first;
  }

  static String _findPin(String text) {
    final match = RegExp(
      r'(?:pin(?:code)?|krascode|security\s*code)\s*[:#-]?\s*([A-Z0-9]{3,10})',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }

  static String _findBalance(String text) {
    final match = RegExp(
      r'(?:€\s*([0-9]+(?:[,.][0-9]{1,2})?)|(?:saldo|balance|tegoed)\s*[:€ ]+([0-9]+(?:[,.][0-9]{1,2})?))',
      caseSensitive: false,
    ).firstMatch(text);
    return (match?.group(1) ?? match?.group(2) ?? '').replaceAll(',', '.');
  }

  static String _suggestName(String text, String type) {
    final line = text
        .split('\n')
        .map((value) => value.trim())
        .firstWhere(
          (value) => value.length >= 3 && value.length <= 40,
          orElse: () => '',
        );
    if (line.isNotEmpty) return line;
    if (type == 'Cadeaukaart') return 'Cadeaukaart';
    if (type == 'QR-code') return 'QR-code';
    return 'Klantenkaart';
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('&', 'en')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}
