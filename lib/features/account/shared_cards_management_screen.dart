import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../data/services/card_share_service.dart';
import '../../data/services/storage_service.dart';
import '../../shared/widgets/card_share_dialogs.dart';

class SharedCardsManagementScreen extends StatefulWidget {
  const SharedCardsManagementScreen({super.key});

  @override
  State<SharedCardsManagementScreen> createState() =>
      _SharedCardsManagementScreenState();
}

class _SharedCardsManagementScreenState
    extends State<SharedCardsManagementScreen> {
  bool _syncing = false;

  List<Map<String, dynamic>> get _cards => StorageService.cardsBox.values
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      await CardShareService.syncAllToLocal();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(
          content: Text(L10n.current.sharedCardsCouldNotBeRefreshed),
        ));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _removeReceived(Map<String, dynamic> card) async {
    final membershipId = card['shareMembershipId']?.toString() ?? '';
    if (membershipId.isEmpty) return;
    await CardShareService.removeReceivedCard(membershipId);
    await CardShareService.syncAllToLocal();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    final incoming = _cards.where((card) => card['isShared'] == true).toList();
    final outgoing = _cards.where((card) =>
        card['isShared'] != true &&
        (card['sharedCardId']?.toString() ?? '').isNotEmpty).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F6),
      appBar: AppBar(
        title:  Text(L10n.current.sharedCards),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF312D35),
        actions: [
          IconButton(
            tooltip: L10n.current.refresh,
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
        children: [
          const _SharingInfo(),
          const SizedBox(height: 20),
          _Section(
            title: L10n.current.sharedByYou,
            empty: L10n.current.youHaveNotSharedAnyCardsYet,
            cards: outgoing,
            actionLabel: L10n.current.manage,
            onAction: (card) => CardShareDialogs.manage(context, card),
          ),
          const SizedBox(height: 20),
          _Section(
            title: L10n.current.sharedWithYou,
            empty: L10n.current.noCardsHaveBeenSharedWithYou,
            cards: incoming,
            actionLabel: L10n.current.delete,
            onAction: _removeReceived,
          ),
        ],
      ),
    );
  }
}

class _SharingInfo extends StatelessWidget {
  const _SharingInfo();

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C438E), Color(0xFF7E62B4)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child:  Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.people_alt_rounded, color: Colors.white, size: 32),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L10n.current.sharingWithControl,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text(
                  L10n.current.seeWhoHasAccessAndStopShared,
                  style: TextStyle(color: Color(0xFFF1EAFF), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String empty;
  final List<Map<String, dynamic>> cards;
  final String actionLabel;
  final ValueChanged<Map<String, dynamic>> onAction;

  const _Section({
    required this.title,
    required this.empty,
    required this.cards,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        if (cards.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(empty,
                style: const TextStyle(color: Color(0xFF706B75))),
          )
        else
          ...cards.map((card) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFFE7ED),
                    child: Icon(
                      card['type'] == 'Cadeaukaart'
                          ? Icons.card_giftcard_rounded
                          : Icons.card_membership_rounded,
                      color: const Color(0xFFD51B46),
                    ),
                  ),
                  title: Text(card['name']?.toString() ?? L10n.current.card,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(L10n.cardType(card['type']?.toString())),
                  trailing: TextButton(
                    onPressed: () => onAction(card),
                    child: Text(actionLabel),
                  ),
                ),
              )),
      ],
    );
  }
}
