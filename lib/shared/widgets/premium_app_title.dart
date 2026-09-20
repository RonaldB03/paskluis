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
        return SizedBox(
          width: double.infinity,
          height: kToolbarHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              if (plus)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFE49A), Color(0xFFD5A021)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Color(0x33A26E00), blurRadius: 8),
                      ],
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      size: 16,
                      color: Color(0xFF6B4A00),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
