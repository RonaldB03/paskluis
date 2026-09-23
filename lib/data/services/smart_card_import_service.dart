import 'barcode_image_service.dart';
import 'card_image_signals.dart';
import '../../shared/utils/card_barcode.dart';
import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mobile;

import '../templates/card_templates.dart';
import 'brand_catalog_service.dart';
import 'brand_recognition.dart';

class SmartCardImportResult {
  final String type;
  final String name;
  final String code;
  final String pinCode;
  final String balance;
  final String codeFormat;
  final String? barcodeSymbology;
  final String expiryDate;
  final CardBrandTemplate? brand;

  const SmartCardImportResult({
    required this.type,
    required this.name,
    required this.code,
    required this.pinCode,
    required this.balance,
    required this.codeFormat,
    this.barcodeSymbology,
    required this.expiryDate,
    this.brand,
  });
}

abstract final class SmartCardImportService {
  static Future<SmartCardImportResult?> pickAndAnalyze({
    ImageSource source = ImageSource.gallery,
  }) async {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 100,
      requestFullMetadata: false,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (image == null) return null;

    return analyzeImage(image.path);
  }

  static Future<SmartCardImportResult> analyzeImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final signals = await readCardImageSignals(
        readBarcodes: () => BarcodeImageService.analyze(imagePath, formats: BarcodeImageService.cardFormats),
        readText: () => recognizer.processImage(InputImage.fromFilePath(imagePath)),
      );
      final scanned = selectCardBarcode(signals.barcodes?.barcodes ?? []);
      final recognized = signals.text;
      final text = recognized?.text.trim() ?? '';
      final brands = await BrandCatalogService.load().timeout(
        const Duration(seconds: 5),
        onTimeout: () => cardBrandTemplates,
      );
      final code = scanned?.rawValue?.trim().isNotEmpty == true
          ? scanned!.rawValue!.trim()
          : _findCardNumber(text);
      final brand = BrandRecognition.match(brands, text: text, code: code);
      final isQr = scanned?.format == mobile.BarcodeFormat.qrCode;
      final giftWords = RegExp(
        r'cadeau|gift\s?card|tegoed|saldo|balance|pin\s?code|krascode',
        caseSensitive: false,
      ).hasMatch(text);
      final brandSupportsGift =
          brand?.supportedTypes.contains('Cadeaukaart') == true;
      final type = isQr
          ? 'QR-code'
          : giftWords || (brandSupportsGift && _findBalance(text).isNotEmpty)
              ? 'Cadeaukaart'
              : 'Pasje';

      return SmartCardImportResult(
        type: type,
        name: brand?.name ?? _suggestName(text, type),
        code: code,
        pinCode: _findPin(text, recognized, code),
        balance: _findBalance(text),
        codeFormat: isQr ? 'qr' : 'barcode',
        barcodeSymbology: scannedBarcodeSymbology(scanned?.format),
        expiryDate: _findExpiryDate(text),
        brand: brand,
      );
    } finally {
      try {
        await recognizer.close();
      } catch (_) {
        // OCR cleanup must not discard an otherwise usable barcode.
      }
    }
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

  static String _findPin(
    String text,
    RecognizedText? recognized,
    String cardCode,
  ) {
    final match = RegExp(
      r'(?:pin(?:code)?|krascode|security\s*code)\s*[:#-]?\s*([A-Z0-9]{3,10})',
      caseSensitive: false,
    ).firstMatch(text);
    final labelled = match?.group(1)?.trim() ?? '';
    if (labelled.isNotEmpty && RegExp(r'\d').hasMatch(labelled)) return labelled;

    final boxes = recognized?.blocks.expand((block) => block.lines).toList() ?? <TextLine>[];
    if (boxes.isEmpty) return '';

    final left = boxes.map((line) => line.boundingBox.left).reduce((a, b) => a < b ? a : b);
    final right = boxes.map((line) => line.boundingBox.right).reduce((a, b) => a > b ? a : b);
    final imageCenter = (left + right) / 2;
    final compactCardCode = cardCode.replaceAll(RegExp(r'\D'), '');

    final candidates = <({String value, double score})>[];
    for (final line in boxes) {
      final raw = line.text.trim();
      if (!RegExp(r'^\d{4,8}$').hasMatch(raw)) continue;
      final value = raw;
      if (compactCardCode.contains(value)) continue;

      var score = 0.0;
      if (RegExp(r'^\s*\d{4,8}\s*$').hasMatch(raw)) score += 40;
      if (value.length == 6) score += 30;
      if (value.length >= 4 && value.length <= 8) score += 12;
      final distance = (line.boundingBox.center.dx - imageCenter).abs();
      score += 30 / (1 + distance / 100);
      candidates.add((value: value, score: score));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.isEmpty ? '' : candidates.first.value;
  }

  static String _findBalance(String text) {
    final match = RegExp(
      r'(?:€\s*([0-9]+(?:[,.][0-9]{1,2})?)|(?:saldo|balance|tegoed)\s*[:€ ]+([0-9]+(?:[,.][0-9]{1,2})?))',
      caseSensitive: false,
    ).firstMatch(text);
    return (match?.group(1) ?? match?.group(2) ?? '').replaceAll(',', '.');
  }

  static String _findExpiryDate(String text) {
    final fullDate = RegExp(
      r'(?:geldig\s*tot|verval(?:datum)?|expiry|expires)?\s*[:\-]?\s*(\d{1,2})[\-\/.](\d{1,2})[\-\/.](\d{2,4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (fullDate != null) {
      final day = int.tryParse(fullDate.group(1) ?? '');
      final month = int.tryParse(fullDate.group(2) ?? '');
      var year = int.tryParse(fullDate.group(3) ?? '');
      if (year != null && year < 100) year += 2000;
      if (day != null && month != null && year != null &&
          day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        return DateTime(year, month, day).toIso8601String();
      }
    }

    final monthYear = RegExp(
      r'(?:geldig\s*tot|verval(?:datum)?|expiry|expires)\s*[:\-]?\s*(\d{1,2})[\-\/.](\d{2,4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (monthYear != null) {
      final month = int.tryParse(monthYear.group(1) ?? '');
      var year = int.tryParse(monthYear.group(2) ?? '');
      if (year != null && year < 100) year += 2000;
      if (month != null && year != null && month >= 1 && month <= 12) {
        return DateTime(year, month + 1, 0).toIso8601String();
      }
    }
    return '';
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
    if (type == 'Cadeaukaart') return L10n.current.cardTypeGift;
    if (type == 'QR-code') return L10n.current.qrCode;
    return L10n.current.cardTypeLoyalty;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('&', 'en')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}
