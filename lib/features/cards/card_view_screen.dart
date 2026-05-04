import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/services/storage_service.dart';
import '../gift_cards/gift_card_view_screen.dart';
import 'edit_card_screen.dart';

class CardViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int initialIndex;

  const CardViewScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<CardViewScreen> createState() => _CardViewScreenState();
}

class _CardViewScreenState extends State<CardViewScreen> {
  late final PageController pageController;
  late List<Map<String, dynamic>> items;
  late int currentIndex;

  double? previousBrightness;

  @override
  void initState() {
    super.initState();

    items = widget.items.map((item) => Map<String, dynamic>.from(item)).toList();
    currentIndex = items.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, items.length - 1).toInt();

    pageController = PageController(
      initialPage: currentIndex,
      viewportFraction: 0.88,
    );

    HapticFeedback.lightImpact();
    setupScreen();
    markCurrentCardAsUsed();
  }

  @override
  void dispose() {
    pageController.dispose();
    restoreScreen();
    super.dispose();
  }

  Future<void> setupScreen() async {
    try {
      previousBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (_) {}

    await WakelockPlus.enable();
  }

  Future<void> restoreScreen() async {
    try {
      if (previousBrightness != null) {
        await ScreenBrightness().setScreenBrightness(previousBrightness!);
      }
    } catch (_) {}

    await WakelockPlus.disable();
  }

  dynamic findKeyById(String id) {
    for (final key in StorageService.cardsBox.keys) {
      final item = StorageService.cardsBox.get(key);

      if (item is Map && item['id']?.toString() == id) {
        return key;
      }
    }

    return null;
  }

  List<Map<String, dynamic>> getLinkedGiftCards(
      Map<String, dynamic> loyaltyCard,
      ) {
    final brandId = loyaltyCard['brandId']?.toString() ?? '';

    if (brandId.isEmpty) return [];

    final giftCards = StorageService.cardsBox.values
        .where(
          (item) =>
      item is Map &&
          item['type'] == 'Cadeaukaart' &&
          item['brandId']?.toString() == brandId,
    )
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    giftCards.sort((a, b) {
      final aFavorite = a['isFavorite'] == true;
      final bFavorite = b['isFavorite'] == true;

      if (aFavorite != bFavorite) return aFavorite ? -1 : 1;

      final aDate = DateTime.tryParse(a['lastUsedAt']?.toString() ?? '') ??
          DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bDate = DateTime.tryParse(b['lastUsedAt']?.toString() ?? '') ??
          DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return giftCards;
  }

  Future<void> openLinkedGiftCards(List<Map<String, dynamic>> giftCards) async {
    if (giftCards.isEmpty) return;

    HapticFeedback.selectionClick();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GiftCardViewScreen(
          items: giftCards,
          initialIndex: 0,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {});
  }

  Future<void> markCurrentCardAsUsed() async {
    if (items.isEmpty) return;

    final item = Map<String, dynamic>.from(items[currentIndex]);
    final id = item['id']?.toString() ?? '';

    if (id.isEmpty) return;

    final key = findKeyById(id);
    if (key == null) return;

    item['lastUsedAt'] = DateTime.now().toIso8601String();
    item['updatedAt'] = DateTime.now().toIso8601String();

    await StorageService.cardsBox.put(key, item);

    if (!mounted) return;

    setState(() {
      items[currentIndex] = item;
    });
  }

  Future<void> updateCurrentItem(Map<String, dynamic> updatedItem) async {
    final id = updatedItem['id']?.toString() ?? '';
    final key = findKeyById(id);

    if (key == null) return;

    final oldItem = Map<String, dynamic>.from(
      StorageService.cardsBox.get(key) as Map,
    );

    final newItem = {
      ...oldItem,
      ...updatedItem,
      'isFavorite': updatedItem['isFavorite'] ?? oldItem['isFavorite'] ?? false,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await StorageService.cardsBox.put(key, newItem);

    if (!mounted) return;

    setState(() {
      items[currentIndex] = Map<String, dynamic>.from(newItem);
    });
  }

  Future<void> toggleFavoriteCurrentItem() async {
    if (items.isEmpty) return;

    final item = Map<String, dynamic>.from(items[currentIndex]);
    item['isFavorite'] = !(item['isFavorite'] == true);

    await updateCurrentItem(item);
    HapticFeedback.selectionClick();
  }

  Future<void> openEdit() async {
    if (items.isEmpty) return;

    HapticFeedback.selectionClick();

    final updatedItem = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditCardScreen(
          item: items[currentIndex],
        ),
      ),
    );

    if (updatedItem == null) return;

    await updateCurrentItem(updatedItem);
  }

  Future<void> confirmDelete() async {
    if (items.isEmpty) return;

    final item = items[currentIndex];
    final name = item['name']?.toString() ?? 'deze kaart';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Kaart verwijderen?'),
          content: Text(
            'Weet je zeker dat je "$name" wilt verwijderen? Dit kun je niet ongedaan maken.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Verwijderen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await deleteCurrentItem();
  }

  Future<void> deleteCurrentItem() async {
    if (items.isEmpty) return;

    final item = items[currentIndex];
    final id = item['id']?.toString() ?? '';
    final key = findKeyById(id);

    if (key == null) return;

    await StorageService.cardsBox.delete(key);

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
    await markCurrentCardAsUsed();
  }

  Barcode getBarcodeType(Map<String, dynamic> item) {
    final code = item['code']?.toString() ?? '';
    final onlyDigits = RegExp(r'^\d+$').hasMatch(code);

    if (onlyDigits && code.length == 13) return Barcode.ean13();
    if (onlyDigits && code.length == 8) return Barcode.ean8();

    return Barcode.code128();
  }

  void copyCurrentCode() {
    if (items.isEmpty) return;

    final code = items[currentIndex]['code']?.toString() ?? '';

    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code gekopieerd'),
      ),
    );
  }

  void openDetails() {
    if (items.isEmpty) return;

    final item = items[currentIndex];
    final code = item['code']?.toString() ?? '';
    final name = item['name']?.toString() ?? 'Kaart';
    final note = item['note']?.toString() ?? '';
    final brandId = item['brandId']?.toString() ?? '';
    final isFavorite = item['isFavorite'] == true;
    final linkedGiftCards = getLinkedGiftCards(item);

    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
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
                  'Kaartdetails',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111122),
                  ),
                ),
                const SizedBox(height: 22),
                _DetailRow(label: 'Naam', value: name),
                const SizedBox(height: 16),
                _DetailRow(
                  label: 'Code',
                  value: code,
                  showCopy: true,
                ),
                if (brandId.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DetailRow(label: 'Merk', value: brandId),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DetailRow(label: 'Notitie', value: note),
                ],
                if (linkedGiftCards.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _LinkedGiftCardAction(
                    giftCards: linkedGiftCards,
                    onTap: () {
                      Navigator.pop(context);
                      openLinkedGiftCards(linkedGiftCards);
                    },
                  ),
                ],
                const SizedBox(height: 24),
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
                _ActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Bewerken',
                  onTap: () {
                    Navigator.pop(context);
                    openEdit();
                  },
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Code kopiëren',
                  onTap: () {
                    Navigator.pop(context);
                    copyCurrentCode();
                  },
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.delete_outline,
                  label: 'Verwijderen',
                  destructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    confirmDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F4F6),
        body: Center(
          child: Text('Geen kaarten'),
        ),
      );
    }

    final currentItem = items[currentIndex];
    final isFavorite = currentItem['isFavorite'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4F6),
        elevation: 0,
        foregroundColor: const Color(0xFF222229),
        leading: const BackButton(),
        centerTitle: true,
        title: Text(
          currentItem['name']?.toString() ?? 'Klantenkaart',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: toggleFavoriteCurrentItem,
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: const Color(0xFFD51B46),
              size: 30,
            ),
          ),
          IconButton(
            onPressed: openDetails,
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Color(0xFF222229),
              size: 30,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: pageController,
              itemCount: items.length,
              onPageChanged: (index) {
                HapticFeedback.selectionClick();
                setState(() => currentIndex = index);
                markCurrentCardAsUsed();
              },
              itemBuilder: (context, index) {
                final item = items[index];
                final linkedGiftCards = getLinkedGiftCards(item);

                return AnimatedBuilder(
                  animation: pageController,
                  builder: (context, child) {
                    double page = currentIndex.toDouble();

                    if (pageController.hasClients &&
                        pageController.position.haveDimensions) {
                      page = pageController.page ?? currentIndex.toDouble();
                    }

                    final distance = (page - index).abs();
                    final scale = (1 - distance * 0.05).clamp(0.94, 1.0);
                    final opacity = (1 - distance * 0.25).clamp(0.65, 1.0);

                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    );
                  },
                  child: _BarcodeCard(
                    item: item,
                    barcode: getBarcodeType(item),
                    linkedGiftCards: linkedGiftCards,
                    onDetails: openDetails,
                    onOpenGiftCards: () => openLinkedGiftCards(linkedGiftCards),
                  ),
                );
              },
            ),
          ),
          if (items.length > 1) ...[
            const SizedBox(height: 8),
            _Dots(
              count: items.length,
              activeIndex: currentIndex,
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Houd de barcode goed voor de scanner',
            style: TextStyle(
              color: Colors.black45,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BarcodeCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Barcode barcode;
  final List<Map<String, dynamic>> linkedGiftCards;
  final VoidCallback onDetails;
  final VoidCallback onOpenGiftCards;

  const _BarcodeCard({
    required this.item,
    required this.barcode,
    required this.linkedGiftCards,
    required this.onDetails,
    required this.onOpenGiftCards,
  });

  Color get brandColor {
    final parsed = int.tryParse(item['brandColor']?.toString() ?? '');
    if (parsed != null) return Color(parsed);
    return const Color(0xFFD51B46);
  }

  bool get hasAssetLogo => (item['logoAsset']?.toString() ?? '').isNotEmpty;

  bool get hasCustomLogo {
    final path = item['customImage']?.toString() ?? '';
    return path.isNotEmpty && File(path).existsSync();
  }

  String get formattedCode {
    final code = item['code']?.toString() ?? '';

    return code
        .replaceAllMapped(
      RegExp(r'.{1,4}'),
          (match) => '${match.group(0)} ',
    )
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'Kaart';
    final code = item['code']?.toString() ?? '';
    final logoAsset = item['logoAsset']?.toString() ?? '';
    final customImage = item['customImage']?.toString() ?? '';
    final hasLinkedGiftCard = linkedGiftCards.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: LinearGradient(
            colors: [
              brandColor,
              brandColor.withOpacity(0.82),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: brandColor.withOpacity(0.28),
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
                height: 142,
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                child: Column(
                  children: [
                    Expanded(
                      child: hasCustomLogo
                          ? Image.file(
                        File(customImage),
                        fit: BoxFit.contain,
                      )
                          : hasAssetLogo
                          ? Image.asset(
                        logoAsset,
                        fit: BoxFit.contain,
                      )
                          : const Icon(
                        Icons.card_membership_rounded,
                        color: Colors.white,
                        size: 70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(34),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7F8),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.04),
                              ),
                            ),
                            child: BarcodeWidget(
                              barcode: barcode,
                              data: code,
                              width: double.infinity,
                              height: hasLinkedGiftCard ? 150 : 180,
                              drawText: false,
                              errorBuilder: (_, __) {
                                return const Center(
                                  child: Text(
                                    'Barcode kan niet worden weergegeven',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        formattedCode,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF111122),
                          fontSize: 20,
                          letterSpacing: 2,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (hasLinkedGiftCard) ...[
                        const SizedBox(height: 14),
                        _LinkedGiftCardInline(
                          giftCards: linkedGiftCards,
                          onTap: onOpenGiftCards,
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onDetails,
                        icon: const Icon(Icons.info_outline_rounded),
                        label: const Text('Details en opties'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD51B46),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
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

class _LinkedGiftCardInline extends StatelessWidget {
  final List<Map<String, dynamic>> giftCards;
  final VoidCallback onTap;

  const _LinkedGiftCardInline({
    required this.giftCards,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = giftCards.length;

    double totalBalance = 0;

    for (final giftCard in giftCards) {
      final raw = giftCard['currentBalance']?.toString() ?? '';
      final value = double.tryParse(raw.replaceAll(',', '.')) ?? 0;
      totalBalance += value;
    }

    final balance = totalBalance > 0
        ? totalBalance.toStringAsFixed(2).replaceAll('.', ',')
        : '';

    return Material(
      color: const Color(0xFFF8E3EA),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFFD51B46),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count > 1
                          ? 'U heeft $count cadeaukaarten beschikbaar'
                          : 'U heeft een cadeaukaart beschikbaar',
                      style: const TextStyle(
                        color: Color(0xFFD51B46),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (balance.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Saldo: € $balance',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFD51B46),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedGiftCardAction extends StatelessWidget {
  final List<Map<String, dynamic>> giftCards;
  final VoidCallback onTap;

  const _LinkedGiftCardAction({
    required this.giftCards,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = giftCards.length;

    double totalBalance = 0;

    for (final giftCard in giftCards) {
      final raw = giftCard['currentBalance']?.toString() ?? '';
      final value = double.tryParse(raw.replaceAll(',', '.')) ?? 0;
      totalBalance += value;
    }

    final balance = totalBalance > 0
        ? totalBalance.toStringAsFixed(2).replaceAll('.', ',')
        : '';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFF8E3EA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.card_giftcard_rounded,
                color: Color(0xFFD51B46),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count > 1
                        ? 'U heeft $count cadeaukaarten beschikbaar'
                        : 'U heeft een cadeaukaart beschikbaar',
                    style: const TextStyle(
                      color: Color(0xFFD51B46),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (balance.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Saldo: € $balance',
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD51B46),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _Dots({
    required this.count,
    required this.activeIndex,
  });

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
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 21,
                    color: Color(0xFF111122),
                    fontWeight: FontWeight.w800,
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gekopieerd'),
                ),
              );
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