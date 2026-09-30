import 'package:paskluis_v1/l10n/l10n.dart';
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
             SnackBar(
              content: Text(L10n.current.unableToUpdateCheckYourConnection),
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
      'barcodeSymbology': result['barcodeSymbology'] ?? '',
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
         SnackBar(content: Text(L10n.current.giftCardSaved)),
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

    final name = item['name']?.toString() ?? L10n.current.thisGiftCard;
    final isShared = item['isShared'] == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          isShared
              ? L10n.current.removeFromYourPaskluis
              : L10n.current.permanentlyDelete,
        ),
        content: Text(
          isShared
              ? L10n.current.youAreOnlyRemovingFromYourOwn433((name).toString())
              : L10n.current.areYouSureYouWantToPermanently434((name).toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:  Text(L10n.current.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD51B46),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isShared ? L10n.current.delete : L10n.current.permanentlyDelete391,
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
           SnackBar(
            content: Text(
              L10n.current.sharedAccessCouldNotBeUpdatedTry,
            ),
          ),
        );
      }
      return;
    }
    await StorageService.deleteCard(key);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(L10n.current.hasBeenDeleted((name).toString()))));
  }

  void showGiftCardOptions(BuildContext context, Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? L10n.current.cardTypeGift;
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
                      ? L10n.current.removeFromMyPaskluis
                      : L10n.current.permanentlyDelete391,
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
               Text(L10n.current.archive435, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              if (archived.isEmpty)
                 Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(L10n.current.thereAreNoGiftCardsInThe),
                )
              else
                ...archived.map((item) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.card_giftcard_rounded)),
                      title: Text(item['name']?.toString() ?? 'Cadeaukaart'),
                      subtitle: Text(
                        L10n.current.balance437((formatAmountValue(item['currentBalance'] ?? '0')).toString()),
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
                            child:  Text(L10n.current.restore),
                          ),
                          IconButton(
                            tooltip: L10n.current.permanentlyDelete391,
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
    L10n.watch(context);
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
            title:  PremiumAppTitle(L10n.current.giftCards),
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
    L10n.watch(context);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (!loadingPlus && !hasPlus)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Material(
                color: const Color(0xFFFFF7D9),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: onOpenPlus,
                  borderRadius: BorderRadius.circular(18),
                  child:  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFA87800),
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.current.moreInformation,
                                style: TextStyle(
                                  color: Color(0xFF6D5000),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                L10n.current.discoverEverythingYouGetWithPaskluisPlus,
                                style: TextStyle(
                                  color: Color(0xFF806719),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFA87800),
                        ),
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
    L10n.watch(context);
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
           Text(
            L10n.current.storeYourFirstGiftCardForFree,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6D5000),
            ),
          ),
          const SizedBox(height: 6),
           Text(
            L10n.current.goFurtherWithPlusStoreUnlimitedGift,
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
            child:  FittedBox(
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
                    L10n.current.text199OnceLifetimeAccess,
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
            label:  Text(L10n.current.discoverAllPlusBenefits),
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
    L10n.watch(context);
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
          child:  Column(
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
                L10n.current.addGiftCard447,
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
                L10n.current.tapToGetStarted,
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
    L10n.watch(context);
    final title = widget.item['name']?.toString() ?? L10n.current.cardTypeGift;
    final logoAsset = widget.item['logoAsset']?.toString() ?? '';
    final customImage = widget.item['customImage']?.toString() ?? '';
    final balance = widget.item['currentBalance']?.toString() ?? '';
    final isFavorite = widget.item['isFavorite'] == true;
    final expiryDate = DateTime.tryParse(widget.item['expiryDate']?.toString() ?? '');
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final expiryDay = expiryDate == null
        ? null
        : DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final daysUntilExpiry = expiryDay?.difference(today).inDays;
    final isExpired = daysUntilExpiry != null && daysUntilExpiry < 0;
    final expiryStatus = isExpired
        ? L10n.current.expired
        : daysUntilExpiry == 0
            ? L10n.current.expiresToday450
            : daysUntilExpiry == 1
                ? L10n.current.text1DayLeft
                : daysUntilExpiry != null && daysUntilExpiry <= 7
                    ? L10n.current.daysLeft((daysUntilExpiry).toString())
                    : null;
    final hasLogo = hasAssetLogo || hasCustomLogo;
    final usesBrandBackground =
        hasLogo && (widget.item['brandColor']?.toString() ?? '').isNotEmpty;
    final hasDarkBrandBackground =
        usesBrandBackground && cardColor.computeLuminance() < 0.55;
    return Semantics(
      button: true,
      label:
          L10n.current.giftCard453((title).toString(), (balance.isEmpty ? L10n.current.balanceUnknown454 : L10n.current.balance455(formatAmountValue(balance))).toString(), (isFavorite ? L10n.current.favourite : '').toString()),
      hint: L10n.current.doubleTapToOpenTheGiftCard,
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
                      ? L10n.current.balanceUnknown
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
              if (expiryStatus != null)
                Positioned(
                  top: 2,
                  left: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: isExpired || daysUntilExpiry == 0
                          ? Colors.red.shade700
                          : const Color(0xFFC68400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      expiryStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
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
    L10n.watch(context);
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
