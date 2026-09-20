import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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

  double? previousBrightness;
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

  Future<void> _setupScreen() async {
    if (SettingsService.autoBrightnessEnabled) {
      try {
        previousBrightness = await ScreenBrightness().current;

        for (final value in [0.65, 0.8, 1.0]) {
          await Future.delayed(const Duration(milliseconds: 90));
          await ScreenBrightness().setScreenBrightness(value);
        }
      } catch (_) {}
    }

    if (SettingsService.keepScreenAwakeEnabled) {
      await WakelockPlus.enable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pageController.dispose();

    if (previousBrightness != null) {
      ScreenBrightness().setScreenBrightness(previousBrightness!);
    }

    if (SettingsService.keepScreenAwakeEnabled) {
      WakelockPlus.disable();
    }
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
    final name = item['name']?.toString() ?? 'deze cadeaukaart';
    final isShared = item['isShared'] == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isShared ? 'Uit jouw PasKluis verwijderen?' : 'Definitief verwijderen?',
          ),
          content: Text(
            isShared
                ? 'Je verwijdert "$name" alleen uit jouw PasKluis. De kaart van de eigenaar blijft bestaan.'
                : 'Weet je zeker dat je "$name" definitief wilt verwijderen? De kaart verdwijnt ook bij iedereen met wie je hem hebt gedeeld. Dit kun je niet ongedaan maken.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(isShared ? 'Verwijderen' : 'Definitief verwijderen'),
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
        const SnackBar(content: Text('Kaarten delen is tijdelijk niet beschikbaar.')),
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
        const SnackBar(content: Text('Kaarten delen is tijdelijk niet beschikbaar.')),
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
                  'Beveiliging niet gelukt',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111122),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We konden je identiteit niet bevestigen. Wil je de pincode toch tonen?',
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
                    label: const Text('Pincode tonen'),
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
                  child: const Text(
                    'Annuleren',
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
    if (items[currentIndex]['isShared'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alleen de eigenaar kan het saldo wijzigen.')),
      );
      return;
    }

    HapticFeedback.selectionClick();

    final item = items[currentIndex];
    final name = item['name']?.toString() ?? 'deze cadeaukaart';
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
                const Text(
                  'Kaart gebruikt?',
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
                      : '$name • huidig saldo € ${formatAmountValue(balance)}',
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
                  label: 'Bedrag besteed',
                  onTap: () {
                    Navigator.pop(context);
                    openBalanceEditor(spentMode: true);
                  },
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Nieuw saldo invoeren',
                  onTap: () {
                    Navigator.pop(context);
                    openBalanceEditor();
                  },
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Kaart volledig gebruikt',
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

  Future<void> _offerArchive() async {
    final archive = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cadeaukaart is leeg'),
        content: const Text('Wil je deze kaart archiveren? Je kunt hem later altijd terugzetten.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Bewaren')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archiveren')),
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
                  spentMode ? 'Bedrag besteed' : 'Nieuw saldo invoeren',
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
                    labelText: spentMode ? 'Besteed bedrag' : 'Nieuw saldo',
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
                      final entered = double.tryParse(controller.text.trim().replaceAll(',', '.'));
                      if (entered == null || entered < 0) return;
                      final oldBalance = _balanceOf(items[currentIndex]);
                      if (spentMode && entered > oldBalance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Het bedrag is hoger dan het huidige saldo.')),
                        );
                        return;
                      }
                      final newBalance = spentMode ? oldBalance - entered : entered;
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
                    label: Text(spentMode ? 'Bedrag verwerken' : 'Saldo opslaan'),
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
              const Text('Saldohistorie', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nog geen saldowijzigingen.'),
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
                          ? '€ ${formatAmountValue(entry['amount'])} besteed'
                          : type == 'used'
                              ? 'Volledig gebruikt'
                              : type == 'undo'
                                  ? 'Wijziging ongedaan gemaakt'
                                  : 'Saldo aangepast';
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
                                child: const Text('Ongedaan'),
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

  Barcode getBarcodeType(Map<String, dynamic> item) {
    final code = item['code']?.toString() ?? '';
    final onlyDigits = RegExp(r'^\d+$').hasMatch(code);

    if (onlyDigits && code.length == 13) return Barcode.ean13();
    if (onlyDigits && code.length == 8) return Barcode.ean8();

    return Barcode.code128();
  }

  void openDetails() {
    if (items.isEmpty) return;

    HapticFeedback.selectionClick();

    final item = items[currentIndex];

    final name = item['name']?.toString() ?? 'Cadeaukaart';
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
                const SnackBar(
                  content: Text('Authenticatie mislukt of geannuleerd'),
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
                          const Expanded(
                            child: Center(
                              child: Text(
                                'Cadeaukaartdetails',
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

                      _DetailRow(label: 'Naam', value: name),
                      if (isShared) ...[
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Toegang',
                          value: canEditShared
                              ? 'Met jou gedeeld • samen bewerken'
                              : 'Met jou gedeeld • alleen bekijken',
                        ),
                      ],
                      const SizedBox(height: 16),

                      _DetailRow(label: 'Barcode', value: code, showCopy: true),

                      if (cardNumber.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: 'Kaartnummer',
                          value: cardNumber,
                          showCopy: true,
                        ),
                      ],

                      if (initialBalance.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: 'Startsaldo',
                          value: '€ $initialBalance',
                        ),
                      ],

                      if (currentBalance.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: 'Huidig saldo',
                          value: '€ ${formatAmountValue(currentBalance)}',
                        ),
                      ],

                      if (expiryDate != null) ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: 'Vervaldatum',
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
                                    const TextSpan(
                                      text: 'Pincode / krascode\n',
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
                              child: Text(sheetShowPin ? 'Getoond' : 'Toon'),
                            ),
                          ],
                        ),
                      ],

                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DetailRow(label: 'Notitie', value: note),
                      ],

                      const SizedBox(height: 24),

                      if (!isShared || canEditShared)
                        _ActionButton(
                          icon: Icons.euro,
                          label: 'Saldo aanpassen',
                          onTap: () {
                            Navigator.pop(context);
                            openBalanceEditor();
                          },
                        ),

                      const SizedBox(height: 10),

                      _ActionButton(
                        icon: Icons.history_rounded,
                        label: 'Saldohistorie',
                        onTap: () {
                          Navigator.pop(context);
                          openBalanceHistory();
                        },
                      ),

                      const SizedBox(height: 10),

                      _ActionButton(
                        icon: isFavorite ? Icons.star : Icons.star_border,
                        label: isFavorite
                            ? 'Verwijder uit favorieten'
                            : 'Maak favoriet',
                        onTap: () async {
                          Navigator.pop(context);
                          await toggleFavoriteCurrentItem();
                        },
                      ),

                      const SizedBox(height: 10),

                      if (!isShared) ...[
                        _ActionButton(
                          icon: Icons.share_rounded,
                          label: 'Delen via e-mailadres',
                          onTap: () {
                            Navigator.pop(context);
                            openShareCard();
                          },
                        ),
                        const SizedBox(height: 10),
                        _ActionButton(
                          icon: Icons.group_outlined,
                          label: 'Gedeelde toegang beheren',
                          onTap: () {
                            Navigator.pop(context);
                            openSharedAccess();
                          },
                        ),
                        const SizedBox(height: 10),
                        _ActionButton(
                          icon: Icons.edit_outlined,
                          label: 'Bewerken',
                          onTap: () {
                            Navigator.pop(context);
                            openEdit(items[currentIndex]);
                          },
                        ),
                      ] else if (canEditShared) ...[
                        _ActionButton(
                          icon: Icons.edit_outlined,
                          label: 'Bewerken',
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
                          label: 'Definitief verwijderen',
                          destructive: true,
                          onTap: () {
                            Navigator.pop(context);
                            confirmDelete();
                          },
                        )
                      else
                        _ActionButton(
                          icon: Icons.remove_circle_outline_rounded,
                          label: 'Uit mijn PasKluis verwijderen',
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
    if (items.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F8FA),
        body: Center(child: Text('Geen cadeaukaarten')),
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
                  tooltip: 'Terug',
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
          const Text(
            'Houd je scherm bij de scanner',
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
    final name = item['name']?.toString() ?? 'Cadeaukaart';
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
                ? const Center(child: Text('Geen barcode beschikbaar'))
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
            Text(
              code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
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
    final name = widget.item['name']?.toString() ?? 'Cadeaukaart';
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
                        tooltip: 'Details en opties',
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
                    'Saldo: € ${formatAmountValue(balance)}',
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
                    label: const Text('Kaart gebruikt?'),
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
                      : BarcodeWidget(
                        barcode: widget.barcode,
                        data: code,
                        width: double.infinity,
                        height: 125,
                        drawText: true,
                        style: const TextStyle(
                          fontSize: 20,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w500,
                        ),
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
                  .showSnackBar(const SnackBar(content: Text('Gekopieerd')));
            },
            child: const Text('Kopiëren'),
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
