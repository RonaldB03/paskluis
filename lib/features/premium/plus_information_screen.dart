import 'package:flutter/material.dart';

import '../account/account_screen.dart';

class PlusInformationScreen extends StatelessWidget {
  final bool showAccountButton;

  const PlusInformationScreen({super.key, this.showAccountButton = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4F0),
      appBar: AppBar(
        title: const Text('PasKluis Plus'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2F2A20),
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
          children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6B4A00), Color(0xFFD5A021)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x30754F00),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.workspace_premium_rounded,
                    color: Color(0xFFFFF2BE), size: 42),
                SizedBox(height: 14),
                Text(
                  'Meer vrijheid. Voor altijd.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Ontgrendel alle cadeaukaart- en deelfuncties met één eenmalige aankoop.',
                  style: TextStyle(
                    color: Color(0xFFFFF8DE),
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 18),
                _PricePill(),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Dit krijg je met Plus',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          const _Benefit(
            icon: Icons.all_inclusive_rounded,
            title: 'Onbeperkt cadeaukaarten',
            subtitle: 'Bewaar zoveel cadeaukaarten als je wilt. Zonder Plus kun je één cadeaukaart bewaren.',
          ),
          const _Benefit(
            icon: Icons.ios_share_rounded,
            title: 'Klanten- én cadeaukaarten delen',
            subtitle: 'Deel veilig via e-mailadres. Een cadeaukaart wordt inclusief pincode of krascode gedeeld.',
          ),
          const _Benefit(
            icon: Icons.edit_note_rounded,
            title: 'Samen beheren',
            subtitle: 'Heeft de ontvanger ook Plus, dan kunnen jullie dezelfde gedeelde kaart allebei bijwerken.',
          ),
          const _Benefit(
            icon: Icons.manage_history_rounded,
            title: 'Gedeelde toegang beheren',
            subtitle: 'Bekijk met wie je kaarten deelt en stop toegang wanneer je wilt.',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7D9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE4C15D)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFFA87800)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Eén keer betalen en geniet voor altijd van PasKluis Plus.',
                    style: TextStyle(
                      color: Color(0xFF6D5000),
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showAccountButton) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD5A021),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountScreen()),
                ),
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text(
                  'Bekijk mijn Plus-status',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'PasKluis is voor iedereen reclamevrij. Plus voegt extra functies toe, geen reclamevrije modus.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF77717D), fontSize: 12.5),
          ),
          ],
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .28)),
      ),
      child: const Text(
        '€ 2 eenmalig  •  levenslange toegang',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Benefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1C8),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: const Color(0xFFA87800)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF6F6A74), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
