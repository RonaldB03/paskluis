import '../../shared/utils/money_input.dart';
import '../../data/services/locale_service.dart';
import '../../shared/utils/card_barcode.dart';
import 'package:paskluis_v1/l10n/l10n.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/card_screen_session.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/services/security_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/card_share_service.dart';
import '../../data/services/settings_service.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/widgets/card_share_dialogs.dart';
import '../../shared/utils/amount_format.dart';
import '../../shared/utils/logo_layout.dart';
import '../premium/plus_information_screen.dart';
import 'edit_gift_card_screen.dart';

class GiftCardViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int initialIndex;

  const GiftCardViewScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<GiftCardViewScreen> createState() => _GiftCardViewScreenState();
}

class _GiftCardViewScreenState extends State<GiftCardViewScreen>
    with WidgetsBindingObserver {
  late final PageController pageController;
  late List<Map<String, dynamic>> items;
  late int currentIndex;

  late final CardScreenSession _screenSession;
  late bool showPin;

  @override
  void initState() {
    super.initState();
    showPin = !SettingsService.hideSensitiveCodes;
    WidgetsBinding.instance.addObserver(this);

    items = widget.items
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    currentIndex = widget.initialIndex.clamp(0, items.length - 1);

    pageController = PageController(
      initialPage: currentIndex,
      viewportFraction: 0.84,
    );

    HapticFeedback.lightImpact();
    _setupScreen();
    markCurrentGiftCardAsUsed();
  }

  void _setupScreen() {
    _screenSession = CardScreenSession(
      brighten: SettingsService.autoBrightnessEnabled,
      keepAwake: SettingsService.keepScreenAwakeEnabled,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pageController.dispose();

    _screenSession.close();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      if (pageController.hasClients) pageController.jumpToPage(currentIndex);
    });
  }

  dynamic _findKeyById(String id) {
    for (final key in StorageService.cardsBox.keys) {
      final item = StorageService.cardsBox.get(key);

      if (item is Map && item['id']?.toString() == id) {
        return key;
      }
    }

    return null;
  }

  Future<void> markCurrentGiftCardAsUsed() async {
    if (items.isEmpty) return;

    final item = Map<String, dynamic>.from(items[currentIndex]);
    final id = item['id']?.toString() ?? '';

    if (id.isEmpty) return;

    final key = _findKeyById(id);
    if (key == null) return;

    item['lastUsedAt'] = DateTime.now().toIso8601String();
    item['updatedAt'] = DateTime.now().toIso8601String();

    await StorageService.saveCard(key, item);
    unawaited(LocationService.rememberCardUse(id));

    if (!mounted) return;

    setState(() {
      items[currentIndex] = item;
    });
  }

  Future<void> updateCurrentItem(Map<String, dynamic> updatedItem) async {
    final id = updatedItem['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final key = _findKeyById(id);
    if (key == null) return;

    final oldItem = StorageService.cardsBox.get(key);

    final newItem = {
      if (oldItem is Map) ...Map<String, dynamic>.from(oldItem),
      ...updatedItem,
      'id': id,
      'type': 'Cadeaukaart',
      'updatedAt': DateTime.now().toIso8601String(),
    };

    var savedItem = Map<String, dynamic>.from(newItem);
    final isReadOnlyShare = savedItem['isShared'] == true &&
        savedItem['canEditShared'] != true;
    if (!isReadOnlyShare &&
        (savedItem['isShared'] == true ||
            (savedItem['sharedCardId']?.toString() ?? '').isNotEmpty)) {
      savedItem = await CardShareService.updateSharedCard(savedItem);
    }

    await StorageService.saveCard(key, savedItem);
    await NotificationService.syncGiftCard(savedItem);

    if (!mounted) return;

    setState(() {
      items[currentIndex] = Map<String, dynamic>.from(savedItem);
    });
  }

  Future<void> toggleFavoriteCurrentItem() async {
    if (items.isEmpty) return;

    final item = Map<String, dynamic>.from(items[currentIndex]);

    item['isFavorite'] = !(item['isFavorite'] == true);
    item['updatedAt'] = DateTime.now().toIso8601String();

    await updateCurrentItem(item);
    HapticFeedback.selectionClick();
  }

  Future<void> deleteCurrentItem() async {
    if (items.isEmpty) return;

    final item = items[currentIndex];
    final id = item['id']?.toString() ?? '';
    final key = _findKeyById(id);

    if (key == null) return;

    await NotificationService.cancelGiftCard(id);
    try {
      if (item['isShared'] == true) {
        await CardShareService.removeReceivedCard(
          item['shareMembershipId']?.toString() ?? '',
        );
      } else if ((item['sharedCardId']?.toString() ?? '').isNotEmpty) {
        await CardShareService.revokeAllForCard(id);
      }
    } catch (_) {
      if (mounted) {
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

    if (!mounted) return;

    HapticFeedback.mediumImpact();

    if (items.length == 1) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      items.removeAt(currentIndex);

      if (currentIndex >= items.length) {
        currentIndex = items.length - 1;
      }
    });

    pageController.jumpToPage(currentIndex);
    await markCurrentGiftCardAsUsed();
  }

  Future<void> confirmDelete() async {
    if (items.isEmpty) return;

    final item = items[currentIndex];
    final name = item['name']?.toString() ?? L10n.current.thisGiftCard;
    final isShared = item['isShared'] == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isShared ? L10n.current.removeFromYourPaskluis : L10n.current.permanentlyDelete,
          ),
          content: Text(
            isShared
                ? L10n.current.youAreOnlyRemovingFromYourOwn((name).toString())
                : L10n.current.areYouSureYouWantToPermanently((name).toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:  Text(L10n.current.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(isShared ? L10n.current.delete : L10n.current.permanentlyDelete391),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await deleteCurrentItem();
    }
  }

  Future<void> openEdit(Map<String, dynamic> item) async {
    HapticFeedback.selectionClick();

    final updatedItem = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditGiftCardScreen(item: item)),
    );

    if (updatedItem == null) return;

    await updateCurrentItem(updatedItem);
  }

  Future<void> openShareCard() async {
    if (items.isEmpty) return;
    if (!SettingsService.cardSharingAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(L10n.current.cardSharingIsTemporarilyUnavailable)),
      );
      return;
    }
    final updated = await CardShareDialogs.share(context, items[currentIndex]);
    if (updated != null) await updateCurrentItem(updated);
  }

  Future<void> openSharedAccess() async {
    if (items.isEmpty) return;
    if (!SettingsService.cardSharingAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(L10n.current.cardSharingIsTemporarilyUnavailable)),
      );
      return;
    }
    await CardShareDialogs.manage(context, items[currentIndex]);
  }

  Future<void> revealPin() async {
    final success = await SecurityService.authenticate();

    if (!mounted) return;

    if (success) {
      setState(() => showPin = true);
      HapticFeedback.selectionClick();
      return;
    }

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(0xFFF8E3EA),
                  child: Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFD51B46),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  L10n.current.verificationFailed,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111122),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  L10n.current.weCouldNotVerifyYourIdentityWould,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.visibility_rounded),
                    label:  Text(L10n.current.showPin),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD51B46),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child:  Text(
                    L10n.current.cancel,
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (confirm == true) {
      setState(() => showPin = true);
      HapticFeedback.selectionClick();
    }
  }

  void openUsedOptions() {
    if (items.isEmpty) return;
    final currentItem = items[currentIndex];
    if (currentItem['isShared'] == true &&
        currentItem['canEditShared'] != true) {
      _showSharedBalancePlusDialog();
      return;
    }

    HapticFeedback.selectionClick();

    final item = items[currentIndex];
    final name = item['name']?.toString() ?? L10n.current.thisGiftCard;
    final balance = item['currentBalance']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 Text(
                  L10n.current.usedThisCard,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111122),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  balance.isEmpty
                      ? name
                      : L10n.current.currentBalance396((name).toString(), (formatAmountValue(balance)).toString()),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                _ActionButton(
                  icon: Icons.shopping_bag_rounded,
                  label: L10n.current.amountSpent,
                  onTap: () {
                    Navigator.pop(context);
                    openBalanceEditor(spentMode: true);
                  },
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.account_balance_wallet_rounded,
                  label: L10n.current.enterNewBalance,
                  onTap: () {
                    Navigator.pop(context);
                    openBalanceEditor();
                  },
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.check_circle_outline_rounded,
                  label: L10n.current.cardFullyUsed,
                  onTap: () async {
                    Navigator.pop(context);
                    await _saveBalance(0, kind: 'used');
                    if (mounted) _offerArchive();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _balanceOf(Map<String, dynamic> item) => double.tryParse(
        (item['currentBalance']?.toString() ?? '').replaceAll(',', '.'),
      ) ?? 0;

  List<Map<String, dynamic>> _historyOf(Map<String, dynamic> item) {
    try {
      final decoded = jsonDecode(item['balanceHistory']?.toString() ?? '[]');
      if (decoded is List) {
        return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  String _money(double value) => normalizeAmountValue(value.toString());

  Future<void> _saveBalance(double newBalance, {required String kind}) async {
    if (items.isEmpty) return;
    final updated = Map<String, dynamic>.from(items[currentIndex]);
    if (updated['isShared'] == true && updated['canEditShared'] != true) {
      await _showSharedBalancePlusDialog();
      return;
    }
    final oldBalance = _balanceOf(updated);
    final history = _historyOf(updated);
    history.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'createdAt': DateTime.now().toIso8601String(),
      'type': kind,
      'oldBalance': _money(oldBalance),
      'newBalance': _money(newBalance),
      'amount': _money((oldBalance - newBalance).abs()),
    });
    updated['currentBalance'] = _money(newBalance);
    updated['balanceHistory'] = jsonEncode(history);
    await updateCurrentItem(updated);
    HapticFeedback.mediumImpact();
  }

  Future<void> _showSharedBalancePlusDialog() async {
    final openPlus = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.workspace_premium_rounded,
          color: Color(0xFFD5A021),
          size: 42,
        ),
        title:  Text(
          L10n.current.manageTogetherWithPlus,
          textAlign: TextAlign.center,
        ),
        content:  Text(
          L10n.current.youCanViewThisSharedGiftCard,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child:  Text(L10n.current.notNow),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.workspace_premium_rounded),
            label:  Text(L10n.current.getPlus199Once),
          ),
        ],
      ),
    );
    if (!mounted || openPlus != true) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlusInformationScreen(),
      ),
    );
  }

  Future<void> _offerArchive() async {
    final archive = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:  Text(L10n.current.giftCardIsEmpty),
        content:  Text(L10n.current.wouldYouLikeToArchiveThisCard),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child:  Text(L10n.current.keep)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child:  Text(L10n.current.archive)),
        ],
      ),
    );
    if (archive != true || items.isEmpty) return;
    final updated = Map<String, dynamic>.from(items[currentIndex]);
    updated['isArchived'] = true;
    updated['archivedAt'] = DateTime.now().toIso8601String();
    await updateCurrentItem(updated);
    if (mounted) Navigator.pop(context);
  }

  void openBalanceEditor({bool spentMode = false}) {
    if (items.isEmpty) return;

    HapticFeedback.selectionClick();

    final item = items[currentIndex];
    final controller = TextEditingController(
      text: spentMode ? '' : item['currentBalance']?.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spentMode ? L10n.current.amountSpent : L10n.current.enterNewBalance,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111122),
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: spentMode ? L10n.current.amountSpent410 : L10n.current.newBalance,
                    prefixText: '€ ',
                    filled: true,
                    fillColor: const Color(0xFFF4F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFD51B46),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final enteredCents = parseMoneyCents(controller.text);
                      final oldCents = parseMoneyCents(items[currentIndex]['currentBalance']?.toString() ?? '');
                      if (enteredCents == null || (spentMode && (enteredCents == 0 || oldCents == null))) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                          LocaleService.languageCode == 'nl'
                            ? 'Vul een geldig bedrag in met maximaal twee decimalen. Stel eerst het saldo in voordat je een uitgave afboekt.'
                            : 'Enter a valid amount with up to two decimal places. Set the balance before recording spending.')));
                        return;
                      }
                      if (spentMode && enteredCents > oldCents!) {
                        ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text(L10n.current.theAmountIsHigherThanTheCurrent)),
                        );
                        return;
                      }
                      final newBalance = (spentMode ? oldCents! - enteredCents : enteredCents) / 100;
                      await _saveBalance(newBalance, kind: spentMode ? 'spent' : 'adjusted');

                      if (!mounted) return;

                      Navigator.pop(context);

                      if (newBalance == 0) {
                        Future.delayed(const Duration(milliseconds: 250), () {
                          if (mounted) _offerArchive();
                        });
                      }
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: Text(spentMode ? L10n.current.applyAmount : L10n.current.saveBalance),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD51B46),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openBalanceHistory() {
    if (items.isEmpty) return;
    final history = _historyOf(items[currentIndex]).reversed.toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text(L10n.current.balanceHistory, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              if (history.isEmpty)
                 Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(L10n.current.noBalanceChangesYet),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .55),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, index) {
                      final entry = history[index];
                      final date = DateTime.tryParse(entry['createdAt']?.toString() ?? '');
                      final type = entry['type']?.toString();
                      final title = type == 'spent'
                          ? L10n.current.spent((formatAmountValue(entry['amount'])).toString())
                          : type == 'used'
                              ? L10n.current.fullyUsed
                              : type == 'undo'
                                  ? L10n.current.changeUndone
                                  : L10n.current.balanceUpdated;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF8E3EA),
                          child: Icon(Icons.receipt_long_rounded, color: Color(0xFFD51B46)),
                        ),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          '${date == null ? '' : '${date.day}-${date.month}-${date.year} • '}€ ${formatAmountValue(entry['oldBalance'])} → € ${formatAmountValue(entry['newBalance'])}',
                        ),
                        trailing: index == 0 && type != 'undo'
                            ? TextButton(
                                onPressed: () async {
                                  final updated = Map<String, dynamic>.from(items[currentIndex]);
                                  final all = _historyOf(updated);
                                  final restored = double.tryParse(entry['oldBalance']?.toString() ?? '') ?? 0;
                                  all.add({
                                    'id': DateTime.now().microsecondsSinceEpoch.toString(),
                                    'createdAt': DateTime.now().toIso8601String(),
                                    'type': 'undo',
                                    'oldBalance': _money(_balanceOf(updated)),
                                    'newBalance': _money(restored),
                                    'amount': '0',
                                  });
                                  updated['currentBalance'] = _money(restored);
                                  updated['balanceHistory'] = jsonEncode(all);
                                  await updateCurrentItem(updated);
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child:  Text(L10n.current.undo),
                              )
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Barcode getBarcodeType(Map<String, dynamic> item) => cardBarcode(
    item['code']?.toString() ?? '',
    symbology: item['barcodeSymbology']?.toString(),
  );

  void openDetails() {
    if (items.isEmpty) return;

    HapticFeedback.selectionClick();

    final item = items[currentIndex];

    final name = item['name']?.toString() ?? L10n.current.cardTypeGift;
    final code = item['code']?.toString() ?? '';
    final note = item['note']?.toString() ?? '';
    final cardNumber = item['cardNumber']?.toString() ?? '';
    final pinCode = item['pinCode']?.toString() ?? '';
    final initialBalance = item['initialBalance']?.toString() ?? '';
    final currentBalance = item['currentBalance']?.toString() ?? '';
    final expiryDate = DateTime.tryParse(item['expiryDate']?.toString() ?? '');
    final isFavorite = item['isFavorite'] == true;
    final isShared = item['isShared'] == true;
    final canEditShared = item['canEditShared'] == true;

    bool sheetShowPin = !SettingsService.hideSensitiveCodes;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> showPinCode() async {
              final success = await SecurityService.authenticate();

              if (!context.mounted) return;

              if (success) {
                setSheetState(() {
                  sheetShowPin = true;
                });
                HapticFeedback.selectionClick();
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                  content: Text(L10n.current.authenticationFailedOrCancelled),
                ),
              );
            }

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    MediaQuery.of(context).viewInsets.bottom + 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                           Expanded(
                            child: Center(
                              child: Text(
                                L10n.current.giftCardDetails424,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111122),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 32),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      _DetailRow(label: L10n.current.name, value: name),
                      if (isShared) ...[
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: L10n.current.access,
                          value: canEditShared
                              ? L10n.current.sharedWithYouEditTogether
                              : L10n.current.sharedWithYouViewOnly,
                        ),
                      ],
                      const SizedBox(height: 16),

                      _DetailRow(label: L10n.current.barcode, value: code, showCopy: true),

                      if (cardNumber.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: L10n.current.cardNumber,
                          value: cardNumber,
                          showCopy: true,
                        ),
                      ],

                      if (initialBalance.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: L10n.current.startingBalance,
                          value: '€ ${formatAmountValue(initialBalance)}',
                        ),
                      ],

                      if (currentBalance.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: L10n.current.currentBalance,
                          value: '€ ${formatAmountValue(currentBalance)}',
                        ),
                      ],

                      if (expiryDate != null) ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: L10n.current.expiryDate,
                          value: '${expiryDate.day.toString().padLeft(2, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.year}',
                        ),
                      ],

                      if (pinCode.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText.rich(
                                TextSpan(
                                  children: [
                                     TextSpan(
                                      text: L10n.current.pinScratchCode427,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    TextSpan(
                                      text: sheetShowPin ? pinCode : '••••••',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        color: Color(0xFF111122),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            FilledButton(
                              onPressed: sheetShowPin ? null : showPinCode,
                              child: Text(sheetShowPin ? L10n.current.visible : L10n.current.actionShow),
                            ),
                          ],
                        ),
                      ],

                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DetailRow(label: L10n.current.note, value: note),
                      ],

                      const SizedBox(height: 24),

                      if (!isShared || canEditShared)
                        _ActionButton(
                          icon: Icons.euro,
                          label: L10n.current.updateBalance,
                          onTap: () {
                            Navigator.pop(context);
                            openBalanceEditor();
                          },
                        )
                      else
                        _ActionButton(
                          icon: Icons.workspace_premium_rounded,
                          label: L10n.current.updateBalanceWithPlus,
                          onTap: () {
                            Navigator.pop(context);
                            _showSharedBalancePlusDialog();
                          },
                        ),

                      const SizedBox(height: 10),

                      _ActionButton(
                        icon: Icons.history_rounded,
                        label: L10n.current.balanceHistory,
                        onTap: () {
                          Navigator.pop(context);
                          openBalanceHistory();
                        },
                      ),

                      const SizedBox(height: 10),

                      _ActionButton(
                        icon: isFavorite ? Icons.star : Icons.star_border,
                        label: isFavorite
                            ? L10n.current.removeFromFavourites
                            : L10n.current.addToFavourites,
                        onTap: () async {
                          Navigator.pop(context);
                          await toggleFavoriteCurrentItem();
                        },
                      ),

                      const SizedBox(height: 10),

                      if (!isShared) ...[
                        _ActionButton(
                          icon: Icons.share_rounded,
                          label: L10n.current.shareByEmail,
                          onTap: () {
                            Navigator.pop(context);
                            openShareCard();
                          },
                        ),
                        const SizedBox(height: 10),
                        _ActionButton(
                          icon: Icons.group_outlined,
                          label: L10n.current.manageSharedAccess,
                          onTap: () {
                            Navigator.pop(context);
                            openSharedAccess();
                          },
                        ),
                        const SizedBox(height: 10),
                        _ActionButton(
                          icon: Icons.edit_outlined,
                          label: L10n.current.edit,
                          onTap: () {
                            Navigator.pop(context);
                            openEdit(items[currentIndex]);
                          },
                        ),
                      ] else if (canEditShared) ...[
                        _ActionButton(
                          icon: Icons.edit_outlined,
                          label: L10n.current.edit,
                          onTap: () {
                            Navigator.pop(context);
                            openEdit(items[currentIndex]);
                          },
                        ),
                      ],

                      const SizedBox(height: 10),

                      if (!isShared)
                        _ActionButton(
                          icon: Icons.delete_forever_rounded,
                          label: L10n.current.permanentlyDelete391,
                          destructive: true,
                          onTap: () {
                            Navigator.pop(context);
                            confirmDelete();
                          },
                        )
                      else
                        _ActionButton(
                          icon: Icons.remove_circle_outline_rounded,
                          label: L10n.current.removeFromMyPaskluis,
                          destructive: true,
                          onTap: () {
                            Navigator.pop(context);
                            confirmDelete();
                          },
                        ),

                      const SizedBox(height: 10),
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

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    if (items.isEmpty) {
      return  Scaffold(
        backgroundColor: Color(0xFFF8F8FA),
        body: Center(child: Text(L10n.current.noGiftCards)),
      );
    }

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (isLandscape) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: pageController,
                itemCount: items.length,
                onPageChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    currentIndex = index;
                    showPin = false;
                  });
                  markCurrentGiftCardAsUsed();
                },
                itemBuilder: (context, index) => _GiftLandscapeBarcode(
                  item: items[index],
                  barcode: getBarcodeType(items[index]),
                ),
              ),
              Positioned(
                left: 8,
                top: 4,
                child: IconButton.filledTonal(
                  tooltip: L10n.current.back,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8FA),
        elevation: 0,
        leading: const BackButton(color: Color(0xFF111122)),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: pageController,
              itemCount: items.length,
              onPageChanged: (index) {
                HapticFeedback.selectionClick();
                setState(() {
                  currentIndex = index;
                  showPin = false;
                });
                markCurrentGiftCardAsUsed();
              },
              itemBuilder: (context, index) {
                final item = items[index];

                return AnimatedBuilder(
                  animation: pageController,
                  builder: (context, child) {
                    double page = currentIndex.toDouble();

                    if (pageController.hasClients &&
                        pageController.position.haveDimensions) {
                      page = pageController.page ?? currentIndex.toDouble();
                    }

                    final distance = (page - index).abs();
                    final scale = (1 - distance * 0.08).clamp(0.90, 1.0);
                    final opacity = (1 - distance * 0.32).clamp(0.55, 1.0);
                    final yOffset = distance * 28;

                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(0, yOffset),
                        child: Transform.scale(scale: scale, child: child),
                      ),
                    );
                  },
                  child: GiftBarcodeCard(
                    item: item,
                    barcode: getBarcodeType(item),
                    onDetails: openDetails,
                    onUsed: openUsedOptions,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (items.length > 1)
            _Dots(count: items.length, activeIndex: currentIndex),
          const SizedBox(height: 20),
           Text(
            L10n.current.holdYourScreenUpToTheScanner,
            style: TextStyle(
              color: Colors.black45,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 26),
        ],
      ),
    );
  }
}

class _GiftLandscapeBarcode extends StatelessWidget {
  final Map<String, dynamic> item;
  final Barcode barcode;

  const _GiftLandscapeBarcode({required this.item, required this.barcode});

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    final name = item['name']?.toString() ?? L10n.current.cardTypeGift;
    final code = item['code']?.toString() ?? '';
    final isQr = item['codeFormat']?.toString() == 'qr';
    return Padding(
      padding: const EdgeInsets.fromLTRB(76, 12, 32, 16),
      child: Column(
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: code.isEmpty
                ?  Center(child: Text(L10n.current.noBarcodeAvailable))
                : isQr
                ? Center(child: QrImageView(data: code, padding: const EdgeInsets.all(8)))
                : BarcodeWidget(
                    barcode: barcode,
                    data: code,
                    width: double.infinity,
                    height: double.infinity,
                    drawText: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                  ),
          ),
          if (!isQr)
            SizedBox(
              height: 24,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  code,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 16,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GiftBarcodeCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final Barcode barcode;
  final VoidCallback onDetails;
  final VoidCallback onUsed;

  const GiftBarcodeCard({
    super.key,
    required this.item,
    required this.barcode,
    required this.onDetails,
    required this.onUsed,
  });

  @override
  State<GiftBarcodeCard> createState() => _GiftBarcodeCardState();
}

class _GiftBarcodeCardState extends State<GiftBarcodeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulseController;
  late final Animation<double> pulseAnimation;

  bool get isQr => widget.item['codeFormat']?.toString() == 'qr';

  @override
  void initState() {
    super.initState();

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    pulseAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    pulseController.dispose();
    super.dispose();
  }

  Color get headerColor {
    final parsed = int.tryParse(widget.item['brandColor']?.toString() ?? '');
    if (parsed != null) return Color(parsed);
    return const Color(0xFFD51B46);
  }

  bool get hasAssetLogo =>
      (widget.item['logoAsset']?.toString() ?? '').isNotEmpty;

  bool get hasCustomLogo {
    final path = widget.item['customImage']?.toString() ?? '';
    return path.isNotEmpty && File(path).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    final name = widget.item['name']?.toString() ?? L10n.current.cardTypeGift;
    final code = widget.item['code']?.toString() ?? '';
    final balance = widget.item['currentBalance']?.toString() ?? '';
    final logoAsset = widget.item['logoAsset']?.toString() ?? '';
    final customImage = widget.item['customImage']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 30, 2, 18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.13),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: Column(
            children: [
              Container(
                height: 125,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                color: headerColor,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 34,
                          vertical: 18,
                        ),
                        child: hasCustomLogo
                            ? Image.file(
                                File(customImage),
                                fit: BoxFit.contain,
                              )
                            : hasAssetLogo
                            ? BrandLogo(
                                source: logoAsset,
                                scale: logoLayoutValue(
                                  widget.item,
                                  'detail',
                                  'scale',
                                  1,
                                ),
                                offsetX: logoLayoutValue(
                                  widget.item,
                                  'detail',
                                  'x',
                                  0,
                                ),
                                offsetY: logoLayoutValue(
                                  widget.item,
                                  'detail',
                                  'y',
                                  0,
                                ),
                              )
                            : Icon(
                                Icons.card_giftcard,
                                color: headerColor.computeLuminance() > 0.55
                                    ? const Color(0xFFD51B46)
                                    : Colors.white,
                                size: 62,
                              ),
                      ),
                    ),
                    if (!hasAssetLogo && !hasCustomLogo)
                      Positioned(
                        bottom: 10,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: headerColor.computeLuminance() > 0.55
                                ? const Color(0xFF303036)
                                : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 0,
                      child: IconButton(
                        tooltip: L10n.current.detailsAndOptions,
                        onPressed: widget.onDetails,
                        icon: const Icon(Icons.more_horiz_rounded),
                        color: headerColor.computeLuminance() > 0.55
                            ? const Color(0xFF303036)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (balance.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  color: const Color(0xFFF8E3EA),
                  child: Text(
                    L10n.current.balance277((formatAmountValue(balance)).toString()),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD51B46),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                color: Colors.white,
                child: SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: widget.onUsed,
                    icon: const Icon(Icons.shopping_bag_rounded),
                    label:  Text(L10n.current.usedThisCard),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD51B46),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: ScaleTransition(
                    scale: pulseAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: isQr
                      ? Center(
                          child: QrImageView(
                            data: code,
                            size: 150,
                            padding: EdgeInsets.zero,
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BarcodeWidget(
                              barcode: widget.barcode,
                              data: code,
                              width: double.infinity,
                              height: 112,
                              drawText: false,
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 27,
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  code,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showCopy;

  const _DetailRow({
    required this.label,
    required this.value,
    this.showCopy = false,
  });

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Row(
      children: [
        Expanded(
          child: SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label\n',
                  style: const TextStyle(fontSize: 15, color: Colors.black54),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Color(0xFF111122),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showCopy)
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context)
                  .showSnackBar( SnackBar(content: Text(L10n.current.copied)));
            },
            child:  Text(L10n.current.copy),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    final color = destructive ? Colors.red : const Color(0xFFD51B46);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: destructive
              ? Colors.red.withOpacity(0.08)
              : const Color(0xFFF8E3EA),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _Dots({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFD51B46) : Colors.black12,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}
