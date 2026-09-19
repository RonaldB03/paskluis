import 'package:flutter/material.dart';

class CardBrandTemplate {
  final String id;
  final String name;
  final String logoAsset;
  final Color color;
  final Map<String, double> logoLayout;

  /// 👇 NIEUW
  final List<String> supportedTypes;

  const CardBrandTemplate({
    required this.id,
    required this.name,
    required this.logoAsset,
    required this.color,
    this.logoLayout = const {},
    this.supportedTypes = const ['Pasje'], // 👈 backward compatible
  });
}

CardBrandTemplate cardBrandTemplateFromJson(Map<String, dynamic> json) {
  final rawColor = (json['brand_color']?.toString() ?? '#D51B46')
      .replaceFirst('#', '');
  final colorValue = int.tryParse('FF$rawColor', radix: 16) ?? 0xFFD51B46;
  final supportedTypes = <String>[
    if (json['supports_loyalty_card'] == true) 'Pasje',
    if (json['supports_gift_card'] == true) 'Cadeaukaart',
  ];

  return CardBrandTemplate(
    id: json['slug']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    logoAsset: json['logo_path']?.toString() ?? '',
    color: Color(colorValue),
    logoLayout: {
      for (final context in const ['home', 'loyalty', 'gift', 'detail', 'picker'])
        ...{
          '${context}Scale': _layoutValue(json['logo_${context}_scale'], 1),
          '${context}X': _layoutValue(json['logo_${context}_x'], 0),
          '${context}Y': _layoutValue(json['logo_${context}_y'], 0),
        },
    },
    supportedTypes: supportedTypes,
  );
}

double _layoutValue(Object? value, double fallback) =>
    double.tryParse(value?.toString() ?? '') ?? fallback;

Map<String, String> logoLayoutCardFields(CardBrandTemplate brand) => {
  for (final entry in brand.logoLayout.entries)
    'logo${entry.key[0].toUpperCase()}${entry.key.substring(1)}':
        entry.value.toString(),
};

/// 🔥 ALLE MERKEN (CENTRAAL)
const List<CardBrandTemplate> cardBrandTemplates = [
  CardBrandTemplate(
    id: 'albert_heijn',
    name: 'Albert Heijn',
    logoAsset: 'assets/logos/albert_heijn.png',
    color: Color(0xFF00A6D6),
    supportedTypes: ['Pasje', 'Cadeaukaart'],
  ),
  CardBrandTemplate(
    id: 'kruidvat',
    name: 'Kruidvat',
    logoAsset: 'assets/logos/kruidvat.png',
    color: Color(0xFFE30613),
    supportedTypes: ['Pasje'],
  ),
  CardBrandTemplate(
    id: 'jumbo',
    name: 'Jumbo',
    logoAsset: 'assets/logos/jumbo.png',
    color: Color(0xFFFFC400),
    supportedTypes: ['Pasje', 'Cadeaukaart'],
  ),
  CardBrandTemplate(
    id: 'hema',
    name: 'HEMA',
    logoAsset: 'assets/logos/hema.png',
    color: Color(0xFFE30613),
    supportedTypes: ['Pasje', 'Cadeaukaart'],
  ),
];

/// 🎯 FILTER HELPER (BELANGRIJK)
List<CardBrandTemplate> getTemplatesByType(String type) {
  return cardBrandTemplates
      .where((brand) => brand.supportedTypes.contains(type))
      .toList();
}
