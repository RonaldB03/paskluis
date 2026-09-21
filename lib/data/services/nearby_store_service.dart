import 'package:supabase_flutter/supabase_flutter.dart';

import 'location_service.dart';
import 'supabase_service.dart';

class NearbyStoreMatch {
  final double distanceMeters;
  final String storeName;
  final String address;

  const NearbyStoreMatch({
    required this.distanceMeters,
    required this.storeName,
    required this.address,
  });
}

abstract final class NearbyStoreService {
  static Future<Map<String, NearbyStoreMatch>> resolveForCards(
    Iterable<Map<String, dynamic>> cards,
    DeviceLocation location,
  ) async {
    final client = SupabaseService.client;
    if (client == null) return const {};

    final brandNames = <String>{};
    final cardBrands = <String, String>{};
    for (final card in cards) {
      final id = card['id']?.toString() ?? '';
      final brand = (card['name']?.toString() ?? '').trim();
      if (id.isEmpty || brand.isEmpty) continue;
      brandNames.add(brand);
      cardBrands[id] = brand;
    }
    if (brandNames.isEmpty) return const {};

    try {
      final response = await client.functions.invoke(
        'nearest-brand-stores',
        body: {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'brands': brandNames.take(20).toList(),
        },
      );
      final data = response.data;
      if (data is! Map || data['matches'] is! Map) return const {};
      final rawMatches = Map<String, dynamic>.from(data['matches'] as Map);
      final byBrand = <String, NearbyStoreMatch>{};
      for (final entry in rawMatches.entries) {
        if (entry.value is! Map) continue;
        final value = Map<String, dynamic>.from(entry.value as Map);
        final distance = double.tryParse(value['distance_meters']?.toString() ?? '');
        if (distance == null) continue;
        byBrand[entry.key] = NearbyStoreMatch(
          distanceMeters: distance,
          storeName: value['store_name']?.toString() ?? entry.key,
          address: value['address']?.toString() ?? '',
        );
      }
      return {
        for (final entry in cardBrands.entries)
          if (byBrand[entry.value] != null) entry.key: byBrand[entry.value]!,
      };
    } on FunctionException {
      return const {};
    } catch (_) {
      return const {};
    }
  }
}
