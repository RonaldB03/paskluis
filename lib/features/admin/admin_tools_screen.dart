import 'package:flutter/material.dart';

import '../account/account_management_screen.dart';
import 'brand_logo_layout_screen.dart';

class AdminToolsScreen extends StatelessWidget {
  const AdminToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F6),
      appBar: AppBar(
        title: const Text('Beheerder'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF312D35),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF302C35),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFFFFE7ED),
                  child: Icon(Icons.admin_panel_settings_rounded,
                      color: Color(0xFFD51B46), size: 30),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Beheerfuncties',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text('Alleen zichtbaar voor beheerders.',
                          style: TextStyle(color: Color(0xFFD8D3DC))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AdminTile(
            icon: Icons.manage_accounts_rounded,
            title: 'Accounts en Plus beheren',
            subtitle: 'Bekijk accounts en beheer handmatige Plus-toegang.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountManagementScreen()),
            ),
          ),
          _AdminTile(
            icon: Icons.tune_rounded,
            title: 'Winkellogo’s passend maken',
            subtitle: 'Stel logo’s af in de echte kaartweergave.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BrandLogoLayoutScreen()),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'Winkels, FAQ’s, app-instellingen, medewerkers en klantenservice beheer je in het centrale PasKluis Beheer.',
              style: TextStyle(color: Color(0xFF706B75), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFE7ED),
          child: Icon(icon, color: const Color(0xFFD51B46)),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
