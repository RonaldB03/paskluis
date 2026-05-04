import 'package:flutter/material.dart';

class CardBrandTemplate {
  final String id;
  final String name;
  final String logoAsset;
  final Color color;

  /// 👇 NIEUW
  final List<String> supportedTypes;

  const CardBrandTemplate({
    required this.id,
    required this.name,
    required this.logoAsset,
    required this.color,
    this.supportedTypes = const ['Pasje'], // 👈 backward compatible
  });
}

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