import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../templates/card_templates.dart';

Future<String?> loadBrandPickerCountry() async {
  final deviceCountry =
      WidgetsBinding.instance.platformDispatcher.locale.countryCode;
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return deviceCountry;
  }

  // On iOS the Flutter locale comes from the preferred languages list.
  // Read the region setting separately so the app language cannot override it.
  try {
    return await const MethodChannel(
      'nl.paskluis.app/device-region',
    ).invokeMethod<String>('countryCode');
  } on MissingPluginException {
    return deviceCountry;
  } on PlatformException {
    return deviceCountry;
  }
}

({List<CardBrandTemplate> popular, List<CardBrandTemplate> stores})
buildBrandPickerCatalog(
  Iterable<CardBrandTemplate> brands, {
  required String query,
  required String? countryCode,
}) {
  final search = query.trim().toLowerCase();
  final hasLocalCountry = countryCode == 'BE' || countryCode == 'NL';
  bool isLocal(CardBrandTemplate brand) =>
      hasLocalCountry && brand.countryCode == countryCode;

  final byName = <String, CardBrandTemplate>{};
  for (final brand in brands) {
    final name = brand.name.trim().toLowerCase();
    if (search.isNotEmpty &&
        !name.contains(search) &&
        !brand.id.toLowerCase().contains(search) &&
        !brand.searchTerms.any((term) => term.contains(search))) {
      continue;
    }

    final existing = byName[name];
    if (existing == null || (isLocal(brand) && !isLocal(existing))) {
      byName[name] = brand;
    }
  }

  final matching = byName.values.toList();
  final preferCountry = matching.any(isLocal);

  matching.sort((first, second) {
    if (preferCountry && isLocal(first) != isLocal(second)) {
      return isLocal(first) ? -1 : 1;
    }
    return first.name.toLowerCase().compareTo(second.name.toLowerCase());
  });

  if (search.isNotEmpty) return (popular: [], stores: matching);

  bool isPopular(CardBrandTemplate brand) =>
      brand.isFeatured && (!preferCountry || isLocal(brand));
  return (
    popular: matching.where(isPopular).toList(),
    stores: matching.where((brand) => !isPopular(brand)).toList(),
  );
}
