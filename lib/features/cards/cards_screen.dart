import 'package:flutter/material.dart';

class CardsScreen extends StatelessWidget {
  final VoidCallback onAdd;

  const CardsScreen({
    super.key,
    required this.onAdd,
  });

  static const List<_DefaultCard> defaultCards = [
    _DefaultCard(
      name: 'Albert Heijn',
      logoAsset: 'assets/logos/albert_heijn.png',
      color: Color(0xFF00A6D6),
    ),
    _DefaultCard(
      name: 'Kruidvat',
      logoAsset: 'assets/logos/kruidvat.png',
      color: Color(0xFFE30613),
    ),
    _DefaultCard(
      name: 'Jumbo',
      logoAsset: 'assets/logos/jumbo.png',
      color: Color(0xFFF6C400),
    ),
    _DefaultCard(
      name: 'HEMA',
      logoAsset: 'assets/logos/hema.png',
      color: Color(0xFFE30613),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Klantenkaarten',
          style: TextStyle(
            color: Color(0xFF3A3A3C),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add, color: Color(0xFFD51B46)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
        children: [
          const Text(
            'Nog geen klantenkaarten toegevoegd',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              height: 1.15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF444446),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Selecteer een kaart die je wilt toevoegen of tik op + voor meer opties',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              height: 1.3,
              color: Color(0xFF555557),
            ),
          ),
          const SizedBox(height: 42),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: defaultCards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.65,
            ),
            itemBuilder: (context, index) {
              final card = defaultCards[index];

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  // Later: open scanner met gekozen winkel
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: card.color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Center(
                    child: Image.asset(
                      card.logoAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 48),

          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.photo_camera_outlined,
                  title: 'Kaart scannen',
                  subtitle: 'Foto maken van fysieke kaart',
                  onTap: onAdd,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ActionCard(
                  icon: Icons.login_outlined,
                  title: 'Importeren',
                  subtitle: 'Overzetten vanuit een andere app',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DefaultCard {
  final String name;
  final String logoAsset;
  final Color color;

  const _DefaultCard({
    required this.name,
    required this.logoAsset,
    required this.color,
  });
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFF8E3EA),
              child: Icon(
                icon,
                color: const Color(0xFFD51B46),
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD51B46),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF444446),
                fontSize: 13,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}