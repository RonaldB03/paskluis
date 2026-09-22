import '../templates/card_templates.dart';

/// Suggest a brand only when the evidence identifies a single managed brand.
abstract final class BrandRecognition {
  static String _words(String value) => value.toLowerCase()
      .replaceAll('&', ' en ').replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static CardBrandTemplate? match(List<CardBrandTemplate> brands, {
    required String text, required String code,
  }) {
    final words = ' ${_words(text)} ';
    final textual = <CardBrandTemplate>[];
    for (final brand in brands) {
      final terms = [brand.name, brand.id, ...brand.searchTerms, ...brand.recognitionKeywords];
      if (terms.map(_words).where((s) => s.length >= 2)
          .any((term) => words.contains(' $term '))) textual.add(brand);
    }
    if (textual.length == 1) return textual.single;
    if (textual.length > 1) return null; // e.g. a multi-store gift card
    final digits = code.replaceAll(RegExp(r'[\s-]'), '');
    var longest = 0;
    final matches = <CardBrandTemplate>{};
    for (final brand in brands) {
      for (final prefix in brand.barcodePrefixes) {
        if (prefix.length < 4 || !digits.startsWith(prefix)) continue;
        if (prefix.length > longest) { longest = prefix.length; matches.clear(); }
        if (prefix.length == longest) matches.add(brand);
      }
    }
    return matches.length == 1 ? matches.single : null;
  }
}
