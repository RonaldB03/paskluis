import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/services/storage_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/card_share_service.dart';
import '../../data/services/account_service.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/utils/amount_format.dart';
import '../../shared/utils/logo_layout.dart';
import '../../shared/widgets/main_bottom_nav.dart';
import '../../shared/widgets/main_tab_swipe_region.dart';
import '../../shared/widgets/premium_app_title.dart';
import '../../shared/widgets/main_tab_route.dart';

import '../cards/card_preview_screen.dart';
import '../cards/cards_screen.dart';
import '../cards/choose_card_template_screen.dart';

import '../home/home_screen.dart';
import '../qr_codes/qr_codes_screen.dart';
import '../premium/premium_gate.dart';
import '../premium/plus_information_screen.dart';

import 'choose_gift_card_template_screen.dart';
import 'gift_card_view_screen.dart';

class GiftCardsScreen extends StatefulWidget {
  const GiftCardsScreen({super.key});

  @override
  State<GiftCardsScreen> createState() => _GiftCardsScreenState();
}

class _GiftCardsScreenState extends State<GiftCardsScreen> {
  bool _hasPlus = false;
  bool _loadingPlus = true;

  @override
  void initState() {
    super.initState();
    _loadPlusStatus();
  }

  Future<void> _loadPlusStatus() async {
    var hasPlus = false;
    if (AccountService.currentUser != null) {
      try {
        hasPlus = (await AccountService.loadPlusStatus()).isActive;
      } catch (_) {
        // Existing local cards remain available while offline.
      }
    }
    if (!mounted) return;
    setState(() {
      _hasPlus = hasPlus;
      _loadingPlus = false;
    });
  }

  Future<void> _refreshGiftCards() async {
    if (AccountService.currentUser != null) {
      try {
        await CardShareService.syncAllToLocal();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bijwerken lukte niet. Controleer je verbinding.'),
            ),
          );
        }
      }
    }
    await _loadPlusStatus();
  }

  Future<void> _openPlus(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlusInformationScreen()),
    );
    await _loadPlusStatus();
  }

  List<Map<String, dynamic>> getItems() {
    final items = StorageService.cardsBox.values
        .where((item) =>
            item is Map &&
            item['type'] == 'Cadeaukaart' &&
            item['isArchived'] != true &&
            item['isArchived']?.toString() != 'true')
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    items.sort((a, b) {
      final aFavorite = a['isFavorite'] == true;
      final bFavorite = b['isFavorite'] == true;

      if (aFavorite != bFavorite) return aFavorite ? -1 : 1;

      final aDate =
          DateTime.tryParse(a['lastUsedAt']?.toString() ?? '') ??
          DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bDate =
          DateTime.tryParse(b['lastUsedAt']?.toString() ?? '') ??
          DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return items;
  }

  Future<Map<String, dynamic>> saveNewCard(
    Map<String, String> result, {
    required String forcedType,
  }) async {
    final now = DateTime.now().toIso8601String();

    final Map<String, dynamic> card = {
      'id': result['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'type': result['type'] ?? forcedType,
      'name': result['name'] ?? '',
      'code': result['code'] ?? '',
      'codeFormat': result['codeFormat'] ?? 'barcode',
      'note': result['note'] ?? '',
      'cardNumber': result['cardNumber'] ?? '',
      'pinCode': result['pinCode'] ?? '',
      'initialBalance': result['initialBalance'] ?? '',
      'currentBalance': result['currentBalance'] ?? '',
      'brandId': result['brandId'] ?? '',
      'logoAsset': result['logoAsset'] ?? '',
      'brandColor': result['brandColor'] ?? '',
      for (final entry in result.entries)
        if (entry.key.startsWith('logo') &&
            (entry.key.endsWith('Scale') ||
                entry.key.endsWith('X') ||
                entry.key.endsWith('Y')))
          entry.key: entry.value,
      'customImage': result['customImage'] ?? '',
      'isFavorite': result['isFavorite'] == 'true',
      'createdAt': result['createdAt'] ?? now,
      'updatedAt': result['updatedAt'] ?? now,
      'lastUsedAt': result['lastUsedAt'] ?? '',
      'balanceHistory': result['balanceHistory'] ?? '[]',
      'expiryDate': result['expiryDate'] ?? '',
      'expiryNotificationsEnabled':
          result['expiryNotificationsEnabled'] == 'true',
      'isArchived': result['isArchived'] == 'true',
    };

    await StorageService.addCard(card);
    try {
      await NotificationService.syncGiftCard(card);
    } catch (_) {
      // Saving the card is the primary action; reminders are best effort.
    }
    return card;
  }

  Future<void> openAddGiftCard(BuildContext context) async {
    if (!await PremiumGate.canAddGiftCard(context)) return;
    if (!context.mounted) return;
    await _loadPlusStatus();
    if (!context.mounted) return;

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const ChooseGiftCardTemplateScreen()),
    );

    if (!context.mounted || result == null) return;

    if (result['persisted'] != 'true') {
      await saveNewCard(result, forcedType: 'Cadeaukaart');
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadeaukaart is opgeslagen.')),
      );
    }
  }

  Future<void> openLoyaltyAddFlow(BuildContext context) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ChooseCardTemplateScreen(type: 'Pasje'),
      ),
    );

    if (!context.mounted || result == null) return;

    final savedCard = await saveNewCard(result, forcedType: 'Pasje');

    if (!context.mounted) return;

    if (result['openPreviewAfterSave'] == 'true') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CardPreviewScreen(
            item: savedCard.map(
              (key, value) => MapEntry(key, value?.toString() ?? ''),
            ),
          ),
        ),
      );
    }
  }

  Future<void> openQrAddFlow(BuildContext context) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ChooseCardTemplateScreen(type: 'QR-code'),
      ),
    );

    if (!context.mounted || result == null) return;

    await saveNewCard(result, forcedType: 'QR-code');
  }

  dynamic findHiveKey(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';

    for (final key in StorageService.cardsBox.keys) {
      final value = StorageService.cardsBox.get(key);

      if (value is Map && value['id']?.toString() == id) {
        return key;
      }
    }

    return null;
  }

  Future<void> deleteGiftCard(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final key = findHiveKey(item);
    if (key == null) return;

    final name = item['name']?.toString() ?? 'deze cadeaukaart';
    final isShared = item['isShared'] == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          isShared
              ? 'Uit jouw PasKluis verwijderen?'
              : 'Definitief verwijderen?',
        ),
        content: Text(
          isShared
              ? 'Je verwijdert "$name" alleen uit jouw PasKluis. De cadeaukaart van de eigenaar blijft bestaan.'
              : 'Weet je zeker dat je "$name" definitief wilt verwijderen? Gedeelde toegang wordt voor iedereen gestopt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD51B46),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isShared ? 'Verwijderen' : 'Definitief verwijderen',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await NotificationService.cancelGiftCard(item['id']?.toString() ?? '');
    try {
      if (isShared) {
        await CardShareService.removeReceivedCard(
          item['shareMembershipId']?.toString() ?? '',
        );
      } else if ((item['sharedCardId']?.toString() ?? '').isNotEmpty) {
        await CardShareService.revokeAllForCard(
          item['id']?.toString() ?? '',
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'De gedeelde toegang kon niet worden bijgewerkt. Probeer het opnieuw met internetverbinding.',
            ),
          ),
        );
      }
      return;
    }
    await StorageService.deleteCard(key);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name is verwijderd.')));
  }

  void showGiftCardOptions(BuildContext context, Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Cadeaukaart';
    final isShared = item['isShared'] == true;

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 16),
                _OptionTile(
                  icon: Icons.delete_rounded,
                  title: isShared
                      ? 'Uit mijn PasKluis verwijderen'
                      : 'Definitief verwijderen',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    deleteGiftCard(context, item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openTab(BuildContext context, int index) {
    Widget screen;

    switch (index) {
      case 0:
        screen = const HomeScreen();
        break;

      case 1:
        screen = const CardsScreen();
        break;

      case 2:
        screen = const QrCodesScreen();
        break;

      case 3:
        return;

      default:
        return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      mainTabRoute(screen, forward: index > 3),
      (_) => false,
    );
  }

  void openHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      mainTabRoute(const HomeScreen(), forward: false),
      (_) => false,
    );
  }

  void openGiftCard(
    BuildContext context,
    List<Map<String, dynamic>> items,
    int index,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GiftCardViewScreen(items: items, initialIndex: index),
      ),
    );
  }

  Future<void> showArchivedCards(BuildContext context) async {
    final archived = StorageService.cardsBox.values
        .where((item) =>
            item is Map &&
            item['type'] == 'Cadeaukaart' &&
            (item['isArchived'] == true || item['isArchived']?.toString() == 'true'))
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Archief', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              if (archived.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('Er staan nog geen cadeaukaarten in het archief.'),
                )
              else
                ...archived.map((item) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.card_giftcard_rounded)),
                      title: Text(item['name']?.toString() ?? 'Cadeaukaart'),
                      subtitle: Text(
                        'Saldo € ${formatAmountValue(item['currentBalance'] ?? '0')}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () async {
                              if (!await PremiumGate.canAddGiftCard(context)) {
                                return;
                              }
                              if (!sheetContext.mounted) return;
                              final key = findHiveKey(item);
                              if (key == null) return;
                              final restored = {
                                ...item,
                                'isArchived': false,
                                'archivedAt': '',
                              };
                              await StorageService.saveCard(key, restored);
                              await NotificationService.syncGiftCard(restored);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            },
                            child: const Text('Terugzetten'),
                          ),
                          IconButton(
                            tooltip: 'Definitief verwijderen',
                            color: Colors.red,
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                              await deleteGiftCard(context, item);
                            },
                            icon: const Icon(Icons.delete_forever_rounded),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) openHome(context);
      },
      child: ValueListenableBuilder<Box>(
      valueListenable: StorageService.cardsBox.listenable(),
      builder: (context, box, _) {
        final items = getItems();

        return Scaffold(
          backgroundColor: const Color(0xFFF4F4F6),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leadingWidth: 56,
            leading: const SizedBox.shrink(),
            title: const PremiumAppTitle('Cadeaukaarten'),
            centerTitle: true,
            titleSpacing: 4,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF333333),
            elevation: 0,
            actions: [
              IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.add, color: Color(0xFFD51B46), size: 32),
                onPressed: () => openAddGiftCard(context),
              ),
            ],
          ),
          body: MainTabSwipeRegion(
            currentIndex: 3,
            onSwitch: (index) => openTab(context, index),
            child: RefreshIndicator(
              onRefresh: _refreshGiftCards,
              color: const Color(0xFFD51B46),
              child: _GiftCardsOverview(
                items: items,
                hasPlus: _hasPlus,
                loadingPlus: _loadingPlus,
                onAdd: () => openAddGiftCard(context),
                onOpenPlus: () => _openPlus(context),
                onOpenCard: (index) => openGiftCard(context, items, index),
                onLongPress: (item) => showGiftCardOptions(context, item),
              ),
            ),
          ),
          bottomNavigationBar: MainBottomNav(
            currentIndex: 3,
            onTap: (index) => openTab(context, index),
          ),
        );
      },
      ),
    );
  }
}

class _GiftCardsOverview extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool hasPlus;
  final bool loadingPlus;
  final VoidCallback onAdd;
  final VoidCallback onOpenPlus;
  final ValueChanged<int> onOpenCard;
  final ValueChanged<Map<String, dynamic>> onLongPress;

  const _GiftCardsOverview({
    required this.items,
    required this.hasPlus,
    required this.loadingPlus,
    required this.onAdd,
    required this.onOpenPlus,
    required this.onOpenCard,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Material(
              color: const Color(0xFFFFF7D9),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onOpenPlus,
                borderRadius: BorderRadius.circular(18),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded,
                          color: Color(0xFFA87800)),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Extra informatie',
                                style: TextStyle(
                                    color: Color(0xFF6D5000),
                                    fontWeight: FontWeight.w900)),
                            Text('Ontdek alles wat je met PasKluis Plus krijgt',
                                style: TextStyle(
                                    color: Color(0xFF806719), fontSize: 12.5)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: Color(0xFFA87800)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: SettingsService.extraClearEnabled ? 1 : 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio:
                  SettingsService.extraClearEnabled ? 2.35 : 1.42,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (items.isEmpty) {
                  return _AddGiftCardTile(onAdd: onAdd);
                }
                final item = items[index];
                return GiftCardTile(
                  item: item,
                  onTap: () => onOpenCard(index),
                  onLongPress: () => onLongPress(item),
                );
              },
              childCount: items.isEmpty ? 1 : items.length,
            ),
          ),
        ),
        if (!hasPlus)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
              child: loadingPlus
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _PlusGiftCardLimitCard(onOpenPlus: onOpenPlus),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _PlusGiftCardLimitCard extends StatelessWidget {
  final VoidCallback onOpenPlus;

  const _PlusGiftCardLimitCard({required this.onOpenPlus});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7D9), Color(0xFFFFE7A0)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD5A021), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFA87800),
            size: 38,
          ),
          const SizedBox(height: 10),
          const Text(
            'Je eerste cadeaukaart is gratis',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6D5000),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ga verder met Plus: bewaar onbeperkt cadeaukaarten en deel klanten- en cadeaukaarten veilig met anderen.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.35, color: Color(0xFF6D5000)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.all_inclusive_rounded,
                    size: 19,
                    color: Color(0xFFA87800),
                  ),
                  SizedBox(width: 7),
                  Text(
                    '€ 2 eenmalig • levenslange toegang',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6D5000),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpenPlus,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD5A021),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.workspace_premium_rounded),
            label: const Text('Ontdek alle Plus-voordelen'),
          ),
        ],
      ),
    );
  }
}

class _AddGiftCardTile extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddGiftCardTile({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF0CCD6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFF8E3EA),
                child: Icon(
                  Icons.add_card_rounded,
                  size: 24,
                  color: Color(0xFFD51B46),
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Voeg cadeaukaart toe',
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF333333),
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Tik om te beginnen',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF77747C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GiftCardTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const GiftCardTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<GiftCardTile> createState() => _GiftCardTileState();
}

class _GiftCardTileState extends State<GiftCardTile> {
  bool isPressed = false;

  bool get hasCustomLogo {
    final path = widget.item['customImage']?.toString() ?? '';
    return path.isNotEmpty && File(path).existsSync();
  }

  bool get hasAssetLogo {
    return (widget.item['logoAsset']?.toString() ?? '').isNotEmpty;
  }

  Color get cardColor {
    final parsed = int.tryParse(widget.item['brandColor']?.toString() ?? '');
    if (parsed != null) return Color(parsed);
    return Colors.white;
  }

  void setPressed(bool value) {
    if (!mounted) return;
    setState(() => isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item['name']?.toString() ?? 'Cadeaukaart';
    final logoAsset = widget.item['logoAsset']?.toString() ?? '';
    final customImage = widget.item['customImage']?.toString() ?? '';
    final balance = widget.item['currentBalance']?.toString() ?? '';
    final isFavorite = widget.item['isFavorite'] == true;
    final expiryDate = DateTime.tryParse(widget.item['expiryDate']?.toString() ?? '');
    final isExpired = expiryDate != null &&
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day)
            .isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    final hasLogo = hasAssetLogo || hasCustomLogo;
    final usesBrandBackground =
        hasLogo && (widget.item['brandColor']?.toString() ?? '').isNotEmpty;
    final hasDarkBrandBackground =
        usesBrandBackground && cardColor.computeLuminance() < 0.55;
    return Semantics(
      button: true,
      label:
          '$title, cadeaukaart, ${balance.isEmpty ? 'saldo onbekend' : 'saldo € ${formatAmountValue(balance)}'}${isFavorite ? ', favoriet' : ''}',
      hint: 'Tik tweemaal om de cadeaukaart te openen',
      child: GestureDetector(
        onTapDown: (_) => setPressed(true),
        onTapCancel: () => setPressed(false),
        onTapUp: (_) => setPressed(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
        scale: isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
          decoration: BoxDecoration(
            color: usesBrandBackground ? cardColor : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isPressed ? 0.035 : 0.06),
                blurRadius: isPressed ? 8 : 12,
                offset: Offset(0, isPressed ? 3 : 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
              Expanded(
                child: ClipRect(
                  child: Center(
                    child: hasLogo
                        ? hasCustomLogo
                            ? Transform.scale(
                                scale: 1.5,
                                child: Image.file(
                                  File(customImage),
                                  fit: BoxFit.contain,
                                  height: 96,
                                  width: double.infinity,
                                ),
                              )
                            : SizedBox(
                                height: 96,
                                width: double.infinity,
                                child: BrandLogo(
                                  source: logoAsset,
                                  scale: logoLayoutValue(
                                    widget.item,
                                    'gift',
                                    'scale',
                                    1,
                                  ),
                                  offsetX: logoLayoutValue(
                                    widget.item,
                                    'gift',
                                    'x',
                                    0,
                                  ),
                                  offsetY: logoLayoutValue(
                                    widget.item,
                                    'gift',
                                    'y',
                                    0,
                                  ),
                                ),
                              )
                        : Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: usesBrandBackground
                                ? Colors.white
                                : const Color(0xFF333333),
                          ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: hasDarkBrandBackground
                      ? Colors.white.withOpacity(0.22)
                      : const Color(0xFFD51B46),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  balance.isEmpty
                      ? 'Saldo onbekend'
                      : '€ ${formatAmountValue(balance)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
                ],
              ),
              if (isFavorite)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.star,
                    color: hasDarkBrandBackground
                        ? Colors.white
                        : const Color(0xFFD51B46),
                    size: 24,
                  ),
                ),
              if (isExpired)
                Positioned(
                  top: 2,
                  left: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Verlopen',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDestructive;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : const Color(0xFFD51B46);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : const Color(0xFF333333),
          fontWeight: FontWeight.w800,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
