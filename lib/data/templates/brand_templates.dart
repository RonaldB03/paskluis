import 'package:flutter/material.dart';

class BrandTemplate {
  final String id;
  final String name;
  final String logoAsset;
  final Color color;
  final List<String> supportedTypes;

  const BrandTemplate({
    required this.id,
    required this.name,
    required this.logoAsset,
    required this.color,
    required this.supportedTypes,
  });
}

const List<BrandTemplate> brandTemplates = [
  BrandTemplate(
    id: 'ah',
    name: 'Albert Heijn',
    logoAsset: 'assets/brands/albert_heijn.png',
    color: Color(0xFF0051A8),
    supportedTypes: ['Pasje', 'Cadeaukaart'],
  ),
  BrandTemplate(
    id: 'hema',
    name: 'HEMA',
    logoAsset: 'assets/brands/hema.png',
    color: Color(0xFFE30613),
    supportedTypes: ['Pasje', 'Cadeaukaart'],
  ),
  BrandTemplate(
    id: 'kruidvat',
    name: 'Kruidvat',
    logoAsset: 'assets/brands/kruidvat.png',
    color: Color(0xFFD50032),
    supportedTypes: ['Pasje'],
  ),
  BrandTemplate(
    id: 'etos',
    name: 'Etos',
    logoAsset: 'assets/brands/etos.png',
    color: Color(0xFF2D2B2B),
    supportedTypes: ['Pasje'],
  ),
  BrandTemplate(
    id: 'bol',
    name: 'bol.com',
    logoAsset: 'assets/brands/bol.png',
    color: Color(0xFF0050A4),
    supportedTypes: ['Cadeaukaart'],
  ),
];