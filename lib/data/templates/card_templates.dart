import 'package:flutter/material.dart';

class CardBrandTemplate {
  final String id;
  final String name;
  final String logoAsset;
  final Color color;

  const CardBrandTemplate({
    required this.id,
    required this.name,
    required this.logoAsset,
    required this.color,
  });
}

const List<CardBrandTemplate> cardBrandTemplates = [
  CardBrandTemplate(
    id: 'albert_heijn',
    name: 'Albert Heijn',
    logoAsset: 'assets/logos/albert_heijn.png',
    color: Color(0xFF00A6D6),
  ),
  CardBrandTemplate(
    id: 'kruidvat',
    name: 'Kruidvat',
    logoAsset: 'assets/logos/kruidvat.png',
    color: Color(0xFFE30613),
  ),
  CardBrandTemplate(
    id: 'jumbo',
    name: 'Jumbo',
    logoAsset: 'assets/logos/jumbo.png',
    color: Color(0xFFFFC400),
  ),
  CardBrandTemplate(
    id: 'hema',
    name: 'HEMA',
    logoAsset: 'assets/logos/hema.png',
    color: Color(0xFFE30613),
  ),
];