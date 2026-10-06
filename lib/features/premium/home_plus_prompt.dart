import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/account_service.dart';
import '../../data/services/locale_service.dart';
import '../../data/services/purchase_service.dart';
import '../../l10n/l10n.dart';
import 'plus_information_screen.dart';

/// Show an upgrade invitation only after inactive access has been confirmed.
class HomePlusPrompt extends StatefulWidget {
  const HomePlusPrompt({super.key});

  @override
  State<HomePlusPrompt> createState() => _HomePlusPromptState();
}

class _HomePlusPromptState extends State<HomePlusPrompt>
    with WidgetsBindingObserver {
  bool _visible = false;
  int _request = 0;
  StreamSubscription<dynamic>? _auth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PurchaseService.revision.addListener(_refresh);
    _auth = AccountService.authChanges?.listen((_) => _refresh());
    _refresh();
  }

  Future<void> _refresh() async {
    final request = ++_request;
    try {
      final status = await AccountService.loadPlusStatus();
      if (mounted && request == _request) {
        setState(() => _visible = !status.isActive);
      }
    } catch (_) {
      if (mounted && request == _request) setState(() => _visible = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PurchaseService.revision.removeListener(_refresh);
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    if (!_visible) return const SizedBox.shrink();
    final nl = LocaleService.languageCode == 'nl';
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Material(
        color: const Color(0xFFFFF2CB),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PlusInformationScreen(),
              ),
            );
            if (mounted) _refresh();
          },
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFF876000),
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  nl
                      ? 'Meer ruimte met PasKluis Plus'
                      : 'More room with PasKluis Plus',
                  style: const TextStyle(
                    color: Color(0xFF513900),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nl
                      ? 'Bewaar onbeperkt cadeaukaarten en deel je kaarten. Eén keer kopen, voor altijd Plus.'
                      : 'Store unlimited gift cards and share your cards. Buy once, enjoy Plus forever.',
                  style: const TextStyle(color: Color(0xFF513900), height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nl ? 'Ontdek PasKluis Plus' : 'Discover PasKluis Plus',
                        style: const TextStyle(
                          color: Color(0xFF513900),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF513900),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
