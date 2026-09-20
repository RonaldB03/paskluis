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

            return Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: plus
                        ? const Color(0xFFD5A021)
                        : Colors.transparent,
                    width: plus ? 2 : 0,
                  ),
                ),
              ),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  indicatorColor: plus
                      ? const Color(0xFFFFE7A3)
                      : const Color(0xFFE2E4FF),
                  labelTextStyle: WidgetStateProperty.resolveWith(
                    (states) => TextStyle(
                      fontSize: labelSize,
                      height: 1,
                      fontWeight: states.contains(WidgetState.selected)
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  iconTheme: WidgetStateProperty.resolveWith(
                    (states) => IconThemeData(
                      color: states.contains(WidgetState.selected) && plus
                          ? const Color(0xFF9A6C00)
                          : null,
                    ),
                  ),
                ),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.0,
                  child: NavigationBar(
                    selectedIndex: currentIndex,
                    onDestinationSelected: onTap,
                    destinations: [
                      const NavigationDestination(
                        icon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.card_membership),
                        label: 'Klantenkaarten',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.qr_code),
                        label: 'QR-codes',
                      ),
                      NavigationDestination(
                        icon: Icon(
                          plus
                              ? Icons.workspace_premium_rounded
                              : Icons.card_giftcard,
                        ),
                        label: 'Cadeaukaarten',
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
