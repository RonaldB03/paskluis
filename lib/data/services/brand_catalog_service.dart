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
}
