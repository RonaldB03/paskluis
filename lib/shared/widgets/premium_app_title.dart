import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';

class PremiumAppTitle extends StatelessWidget {
  final String title;

  const PremiumAppTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlusStatus>(
      future: AccountService.loadPlusStatus(),
      builder: (context, snapshot) => AppTitleWithPlus(
        title: title,
        plus: snapshot.data?.isActive == true,
      ),
    );
  }
}

/// Keeps the title and status together on narrow and large-text screens.
class AppTitleWithPlus extends StatelessWidget {
  final String title;
  final bool plus;

  const AppTitleWithPlus({required this.title, required this.plus, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              if (plus) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE7A3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PLUS',
                    style: TextStyle(
                      color: Color(0xFF654600),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
