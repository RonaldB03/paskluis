import 'package:paskluis_v1/l10n/l10n.dart';
import '../templates/card_templates.dart';
import 'supabase_service.dart';

abstract final class BrandCatalogService {
  static Future<List<CardBrandTemplate>> load() async {
    final client = SupabaseService.client;
    if (client == null) return cardBrandTemplates;

    try {
      final rows = await client
          .from('brands')
          .select()
          .eq('is_active', true)
          .order('sort_order')
          .order('name');
      final brands = rows
          .map<CardBrandTemplate>(
            (row) => cardBrandTemplateFromJson(Map<String, dynamic>.from(row)),
          )
          .where((brand) => brand.id.isNotEmpty && brand.name.isNotEmpty)
          .toList();
      return brands.isEmpty ? cardBrandTemplates : brands;
    } catch (_) {
      return cardBrandTemplates;
    }
  }

  /// Loads the complete managed catalogue without silently falling back to
  /// bundled demo brands. The admin editor must never save against a partial
  /// or stale fallback list.
  static Future<List<CardBrandTemplate>> loadForAdmin() async {
    final client = SupabaseService.client;
    if (client == null) {
      throw StateError(L10n.current.onlineServicesAreUnavailable);
    }

    final rows = await client
        .from('brands')
        .select()
        .order('sort_order')
        .order('name');
    final brands = rows
        .map<CardBrandTemplate>(
          (row) => cardBrandTemplateFromJson(Map<String, dynamic>.from(row)),
        )
        .where((brand) => brand.id.isNotEmpty && brand.name.isNotEmpty)
        .toList();
    if (brands.isEmpty) {
      throw StateError(L10n.current.noStoresFound);
    }
    return brands;
  }

  static Future<void> updateLogoLayout({
    required String brandSlug,
    required Map<String, double> layout,
  }) async {
    final client = SupabaseService.client;
    if (client == null) {
      throw StateError(L10n.current.onlineServicesAreUnavailable);
    }

    final payload = <String, double>{
      for (final context in const [
        'home',
        'loyalty',
        'gift',
        'detail',
        'picker',
      ]) ...{
        'logo_${context}_scale': layout['${context}Scale'] ?? 1,
        'logo_${context}_x': layout['${context}X'] ?? 0,
        'logo_${context}_y': layout['${context}Y'] ?? 0,
      },
    };

    final updated = await client
        .from('brands')
        .update({
          ...payload,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('slug', brandSlug)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError(L10n.current.theStoreCouldNotBeUpdated);
    }
  }
}
