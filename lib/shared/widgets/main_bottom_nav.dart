import 'package:flutter/material.dart';

class MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.card_membership),
          label: 'Klantenkaarten',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code),
          label: 'QR-codes',
        ),
        NavigationDestination(
          icon: Icon(Icons.card_giftcard),
          label: 'Cadeaukaarten',
        ),
      ],
    );
  }
}