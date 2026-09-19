import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';

class PremiumAppTitle extends StatelessWidget {
  final String title;

  const PremiumAppTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlusStatus>(
      future: AccountService.loadPlusStatus(),
      builder: (context, snapshot) {
        final plus = snapshot.data?.isActive == true;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (plus) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE49A), Color(0xFFD5A021)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33A26E00), blurRadius: 8),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 14),
                    SizedBox(width: 3),
                    Text(
                      'PLUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
