import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';

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
    L10n.watch(context);
    return FutureBuilder<PlusStatus>(
      future: AccountService.loadPlusStatus(),
      builder: (context, snapshot) {
        final plus = snapshot.data?.isActive == true;
        return LayoutBuilder(
          builder: (context, constraints) {
            // Four destinations leave little label space on compact iPhones.
            // Adapt only the navigation labels so they remain on one line.
            final labelSize = constraints.maxWidth < 360
                ? 8.0
                : constraints.maxWidth < 400
                ? 10.0
                : 11.0;

            return SafeArea(
              top: false,
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: const Color(0xFFF8F7FC),
                  indicatorColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: WidgetStateProperty.resolveWith(
                    (states) => IconThemeData(
                      color: states.contains(WidgetState.selected)
                          ? const Color(0xFFD51B46)
                          : const Color(0xFF2F2D35),
                      size: 25,
                    ),
                  ),
                  labelTextStyle: WidgetStateProperty.resolveWith(
                    (states) => TextStyle(
                      color: states.contains(WidgetState.selected)
                          ? const Color(0xFF26242B)
                          : const Color(0xFF55535B),
                      fontSize: labelSize,
                      height: 1,
                      fontWeight: states.contains(WidgetState.selected)
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.0,
                  child: NavigationBar(
                    height: 78,
                    selectedIndex: currentIndex,
                    onDestinationSelected: onTap,
                    destinations: [
                       NavigationDestination(
                        icon: _NavIcon(icon: Icons.home_rounded),
                        selectedIcon: _NavIcon(
                          icon: Icons.home_rounded,
                          selected: true,
                        ),
                        label: L10n.current.home,
                      ),
                       NavigationDestination(
                        icon: _NavIcon(icon: Icons.card_membership),
                        selectedIcon: _NavIcon(
                          icon: Icons.card_membership,
                          selected: true,
                        ),
                        label: L10n.current.loyaltyCards,
                      ),
                       NavigationDestination(
                        icon: _NavIcon(icon: Icons.qr_code),
                        selectedIcon: _NavIcon(
                          icon: Icons.qr_code,
                          selected: true,
                        ),
                        label: L10n.current.qrCodes478,
                      ),
                      NavigationDestination(
                        icon: _NavIcon(
                          icon: plus
                              ? Icons.workspace_premium_rounded
                              : Icons.card_giftcard,
                        ),
                        selectedIcon: _NavIcon(
                          icon: plus
                              ? Icons.workspace_premium_rounded
                              : Icons.card_giftcard,
                          selected: true,
                        ),
                        label: L10n.current.giftCards,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;

  const _NavIcon({required this.icon, this.selected = false});

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return SizedBox(
      width: 34,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 0, child: Icon(icon, size: 25)),
          if (selected)
            Positioned(
              bottom: 0,
              child: Container(
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFD51B46),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
