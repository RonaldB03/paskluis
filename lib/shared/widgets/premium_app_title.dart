import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';
import '../../features/premium/plus_information_screen.dart';
import '../../l10n/l10n.dart';

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title, maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          if (plus) ...[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: L10n.current.viewMyPlusStatus,
              child: Tooltip(
                message: L10n.current.viewMyPlusStatus,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const PlusInformationScreen(isActive: true),
                  )),
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2CC68),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD6AD43)),
                        ),
                        child: const Text('PLUS',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: Color(0xFF513900),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
