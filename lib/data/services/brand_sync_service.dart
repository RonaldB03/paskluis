import 'brand_catalog_service.dart';
import 'storage_service.dart';

/// Keeps cards linked to managed brands in sync with the latest admin logo
/// and colour, without overwriting a user-selected custom image.
abstract final class BrandSyncService {
  static Future<void> refreshSavedCards() async {
    final brands = await BrandCatalogService.load();
    final byId = {for (final brand in brands) brand.id: brand};

    for (final key in StorageService.cardsBox.keys.toList()) {
      final raw = StorageService.cardsBox.get(key);
      if (raw is! Map) continue;
      final card = Map<String, dynamic>.from(raw);
      final brandId = card['brandId']?.toString() ?? '';
      final brand = byId[brandId];
      if (brand == null) continue;

      final nextLogo = brand.logoAsset;
      final nextColor = brand.color.value.toString();
      if (card['logoAsset']?.toString() == nextLogo &&
          card['brandColor']?.toString() == nextColor) {
        continue;
      }

      card['logoAsset'] = nextLogo;
      card['brandColor'] = nextColor;
      card['updatedAt'] = DateTime.now().toIso8601String();
      await StorageService.saveCard(key, card);
    }
  }
}
