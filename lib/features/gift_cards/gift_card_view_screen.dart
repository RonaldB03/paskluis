import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/services/security_service.dart';
import '../../data/services/storage_service.dart';
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

class _GiftCardViewScreenState extends State<GiftCardViewScreen> {
  late final PageController pageController;
  late List<Map<String, dynamic>> items;
  late int currentIndex;
  double? previousBrightness;
  bool showPin = false;

  @override
  void initState() {
    super.initState();

    items = widget.items.map((item) => Map<String, dynamic>.from(item)).toList();
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
    try {
      previousBrightness = await ScreenBrightness().current;

      for (final value in [0.65, 0.8, 1.0]) {
        await Future.delayed(const Duration(milliseconds: 90));
        await ScreenBrightness().setScreenBrightness(value);
      }
    } catch (_) {}

    await WakelockPlus.enable();
  }

  @override
  void dispose() {
    pageController.dispose();

    if (previousBrightness != null) {
      ScreenBrightness().setScreenBrightness(previousBrightness!);
    }

    WakelockPlus.disable();
    super.dispose();
  }

  dynamic _findKeyById(String id) {
    for (final key in StorageService.cardsBox.keys) {
      final item = StorageService.cardsBox.get(key);

      if (item is Map && item['id'] == id) {
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

    await StorageService.cardsBox.put(key, item);

    if (!mounted) return;

    setState(() {
      items[currentIndex] = item;
    });
  }

  Future<void> updateCurrentItem(Map<String, dynamic> updatedItem) async {
    final id = updatedItem['id']?.toString() ?? '';
    final key = _findKeyById(id);

    if (key == null) return;

    updatedItem['updatedAt'] = DateTime.now().toIso8601String();

    await StorageService.cardsBox.put(key, updatedItem);

    if (!mounted) return;

    setState(() {
      items[currentIndex] = Map<String, dynamic>.from(updatedItem);
    });
  }

  Future<void> toggleFavoriteCurrentItem() async {
    final item = Map<String, dynamic>.from(items[currentIndex]);

    item['isFavorite'] = !(item['isFavorite'] == true);
    item['updatedAt'] = DateTime.now().toIso8601String();

    await updateCurrentItem(item);

    HapticFeedback.selectionClick();
  }

  Future<void> deleteCurrentItem() async {
    final item = items[currentIndex];
    final id = item['id']?.toString() ?? '';
    final key = _findKeyById(id);

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
    await markCurrentGiftCardAsUsed();
  }

  Future<void> confirmDelete() async {
    final item = items[currentIndex];
    final name = item['name']?.toString() ?? 'deze cadeaukaart';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cadeaukaart verwijderen?'),
          content: Text(
            'Weet je zeker dat je "$name" wilt verwijderen? Dit kun je niet ongedaan maken.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Verwijderen'),
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
      MaterialPageRoute(
        builder: (_) => EditGiftCardScreen(item: item),
      ),
    );

    if (updatedItem == null) return;

    await updateCurrentItem(updatedItem);
  }

  Future<void> revealPin() async {
    final success = await SecurityService.authenticate();

    if (!mounted) return;

    if (success) {
      setState(() => showPin = true);
      HapticFeedback.selectionClick();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authenticatie mislukt of geannuleerd')),
      );
    }
  }

  void openBalanceEditor() {
    HapticFeedback.selectionClick();

    final item = items[currentIndex];
    final controller = TextEditingController(
      text: item['currentBalance']?.toString() ?? '',
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
                const Text(
                  'Saldo aanpassen',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111122),
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Nieuw saldo',
                    prefixText: '€ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    final newBalance = controller.text.trim();

                    final updated = Map<String, dynamic>.from(items[currentIndex]);
                    updated['currentBalance'] = newBalance;

                    await updateCurrentItem(updated);

                    if (!mounted) return;

                    Navigator.pop(context);

                    if (newBalance == '0' ||
                        newBalance == '0.00' ||
                        newBalance == '0,00') {
                      Future.delayed(const Duration(milliseconds: 250), () {
                        if (mounted) confirmDelete();
                      });
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Opslaan'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Barcode getBarcodeType(Map<String, dynamic> item) {
    final code = item['code']?.toString() ?? '';
    final onlyDigits = RegExp(r'^\d+$').hasMatch(code);

    if (onlyDigits && code.length == 13) {
      return Barcode.ean13();
    }

    if (onlyDigits && code.length == 8) {
      return Barcode.ean8();
    }

    return Barcode.code128();
  }

  void openDetails() {
    HapticFeedback.selectionClick();

    final item = items[currentIndex];

    final name = item['name']?.toString() ?? 'Cadeaukaart';
    final code = item['code']?.toString() ?? '';
    final note = item['note']?.toString() ?? '';
    final cardNumber = item['cardNumber']?.toString() ?? '';
    final pinCode = item['pinCode']?.toString() ?? '';
    final initialBalance = item['initialBalance']?.toString() ?? '';
    final currentBalance = item['currentBalance']?.toString() ?? '';
    final isFavorite = item['isFavorite'] == true;

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
                  _DetailRow(label: 'Startsaldo', value: '€ $initialBalance'),
                ],

                if (currentBalance.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DetailRow(label: 'Huidig saldo', value: '€ $currentBalance'),
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
                                text: showPin ? pinCode : '••••••',
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
                        onPressed: showPin ? null : revealPin,
                        child: Text(showPin ? 'Getoond' : 'Toon'),
                      ),
                    ],
                  ),
                ],

                if (note.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DetailRow(label: 'Notitie', value: note),
                ],

                const SizedBox(height: 24),

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
                    openEdit(items[currentIndex]);
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
        backgroundColor: Color(0xFFF8F8FA),
        body: Center(child: Text('Geen cadeaukaarten')),
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
                        child: Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _GiftBarcodeCard(
                    item: item,
                    barcode: getBarcodeType(item),
                    onDetails: openDetails,
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

class _GiftBarcodeCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final Barcode barcode;
  final VoidCallback onDetails;

  const _GiftBarcodeCard({
    required this.item,
    required this.barcode,
    required this.onDetails,
  });

  @override
  State<_GiftBarcodeCard> createState() => _GiftBarcodeCardState();
}

class _GiftBarcodeCardState extends State<_GiftBarcodeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulseController;
  late final Animation<double> pulseAnimation;

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
                height: 118,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                color: headerColor,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 29,
                      backgroundColor: Colors.white.withOpacity(0.20),
                      child: hasCustomLogo
                          ? ClipOval(
                        child: Image.file(
                          File(customImage),
                          width: 50,
                          height: 50,
                          fit: BoxFit.contain,
                        ),
                      )
                          : hasAssetLogo
                          ? Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          logoAsset,
                          fit: BoxFit.contain,
                        ),
                      )
                          : const Icon(
                        Icons.card_giftcard,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onDetails,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.16),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text(
                        'Details',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              if (balance.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  color: const Color(0xFFF8E3EA),
                  child: Text(
                    'Saldo: € $balance',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD51B46),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: ScaleTransition(
                    scale: pulseAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: BarcodeWidget(
                        barcode: widget.barcode,
                        data: code,
                        width: double.infinity,
                        height: 160,
                        drawText: true,
                        style: const TextStyle(
                          fontSize: 22,
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gekopieerd')),
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