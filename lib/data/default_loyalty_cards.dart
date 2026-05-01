class DefaultLoyaltyCard {
  final String id;
  final String name;
  final String logoAsset;
  final String brandColor;

  const DefaultLoyaltyCard({
    required this.id,
    required this.name,
    required this.logoAsset,
    required this.brandColor,
  });
}

const defaultLoyaltyCards = [
  DefaultLoyaltyCard(
    id: 'albert_heijn',
    name: 'Albert Heijn',
    logoAsset: 'assets/logos/albert_heijn.png',
    brandColor: '#00A6D6',
  ),
  DefaultLoyaltyCard(
    id: 'kruidvat',
    name: 'Kruidvat',
    logoAsset: 'assets/logos/kruidvat.png',
    brandColor: '#E30613',
  ),
  DefaultLoyaltyCard(
    id: 'jumbo',
    name: 'Jumbo',
    logoAsset: 'assets/logos/jumbo.png',
    brandColor: '#F6C400',
  ),
  DefaultLoyaltyCard(
    id: 'hema',
    name: 'HEMA',
    logoAsset: 'assets/logos/hema.png',
    brandColor: '#E30613',
  ),
];