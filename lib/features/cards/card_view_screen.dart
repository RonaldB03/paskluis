import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  late int currentIndex;
  double? previousBrightness;

  @override
  void initState() {
    super.initState();

    currentIndex = widget.initialIndex;

    pageController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 0.84,
    );

    HapticFeedback.lightImpact();
    _setupScreen();
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

  Barcode getBarcodeType(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? '';
    final code = item['code']?.toString() ?? '';

    if (type == 'QR-code') {
      return Barcode.qrCode();
    }

    final onlyDigits = RegExp(r'^\d+$').hasMatch(code);

    if (onlyDigits && code.length == 13) {
      return Barcode.ean13();
    }

    if (onlyDigits && code.length == 8) {
      return Barcode.ean8();
    }

    return Barcode.code128();
  }

  bool isQrCode(Map<String, dynamic> item) {
    return item['type']?.toString() == 'QR-code';
  }

  void openDetails(Map<String, dynamic> item) {
    HapticFeedback.selectionClick();

    final code = item['code']?.toString() ?? '';
    final name = item['name']?.toString() ?? 'Kaart';
    final note = item['note']?.toString() ?? '';
    final type = item['type']?.toString() ?? '';

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
                          'Kaartdetails',
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
                const SizedBox(height: 24),
                _DetailRow(label: 'Type', value: type),
                const SizedBox(height: 18),
                _DetailRow(label: 'Naam', value: name),
                const SizedBox(height: 18),
                _DetailRow(
                  label: 'Code',
                  value: code,
                  showCopy: true,
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _DetailRow(label: 'Notitie', value: note),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
              itemCount: widget.items.length,
              onPageChanged: (index) {
                HapticFeedback.selectionClick();
                setState(() => currentIndex = index);
              },
              itemBuilder: (context, index) {
                final item = widget.items[index];

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
                  child: _BarcodeCard(
                    item: item,
                    barcode: getBarcodeType(item),
                    isQr: isQrCode(item),
                    onDetails: () => openDetails(item),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (widget.items.length > 1)
            _Dots(
              count: widget.items.length,
              activeIndex: currentIndex,
            ),
          const SizedBox(height: 22),
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

class _BarcodeCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final Barcode barcode;
  final bool isQr;
  final VoidCallback onDetails;

  const _BarcodeCard({
    required this.item,
    required this.barcode,
    required this.isQr,
    required this.onDetails,
  });

  @override
  State<_BarcodeCard> createState() => _BarcodeCardState();
}

class _BarcodeCardState extends State<_BarcodeCard>
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
      CurvedAnimation(
        parent: pulseController,
        curve: Curves.easeInOut,
      ),
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
    return const Color(0xFF2D2B2B);
  }

  bool get hasAssetLogo =>
      (widget.item['logoAsset']?.toString() ?? '').isNotEmpty;

  bool get hasCustomLogo {
    final path = widget.item['customImage']?.toString() ?? '';
    return path.isNotEmpty && File(path).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name']?.toString() ?? 'Kaart';
    final code = widget.item['code']?.toString() ?? '';
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
                height: 98,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                color: headerColor,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: Colors.white.withOpacity(0.20),
                      child: hasCustomLogo
                          ? ClipOval(
                        child: Image.file(
                          File(customImage),
                          width: 48,
                          height: 48,
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
                        Icons.card_membership,
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
                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: BarcodeWidget(
                        barcode: widget.barcode,
                        data: code,
                        width: double.infinity,
                        height: widget.isQr ? 260 : 170,
                        drawText: !widget.isQr,
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