import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'gift_card_scanner_screen.dart';

class AddGiftCardScreen extends StatefulWidget {
  final bool isEditing;
  final String? initialName;
  final String? initialCode;
  final String? initialCardNumber;
  final String? initialPinCode;
  final String? initialInitialBalance;
  final String? initialCurrentBalance;
  final String? initialNote;
  final String? initialBrandId;
  final String? initialLogoAsset;
  final String? initialBrandColor;
  final String? initialCustomImage;

  const AddGiftCardScreen({
    super.key,
    this.isEditing = false,
    this.initialName,
    this.initialCode,
    this.initialCardNumber,
    this.initialPinCode,
    this.initialInitialBalance,
    this.initialCurrentBalance,
    this.initialNote,
    this.initialBrandId,
    this.initialLogoAsset,
    this.initialBrandColor,
    this.initialCustomImage,
  });

  @override
  State<AddGiftCardScreen> createState() => _AddGiftCardScreenState();
}

class _AddGiftCardScreenState extends State<AddGiftCardScreen> {
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final balanceController = TextEditingController();
  final pinCodeController = TextEditingController();
  final noteController = TextEditingController();

  String brandId = '';
  String logoAsset = '';
  String brandColor = '';
  String customImage = '';

  bool get hasAssetLogo => logoAsset.isNotEmpty;

  bool get hasCustomLogo =>
      customImage.isNotEmpty && File(customImage).existsSync();

  Color get cardColor {
    final parsed = int.tryParse(brandColor);
    if (parsed != null) return Color(parsed);
    return const Color(0xFFD51B46);
  }

  Barcode get barcodeType {
    final code = codeController.text.trim();
    final onlyDigits = RegExp(r'^\d+$').hasMatch(code);

    if (onlyDigits && code.length == 13) return Barcode.ean13();
    if (onlyDigits && code.length == 8) return Barcode.ean8();

    return Barcode.code128();
  }

  String get formattedCode {
    final code = codeController.text.trim();

    return code
        .replaceAllMapped(
      RegExp(r'.{1,4}'),
          (match) => '${match.group(0)} ',
    )
        .trim();
  }

  @override
  void initState() {
    super.initState();

    nameController.text = widget.initialName ?? '';
    codeController.text = widget.initialCode ?? widget.initialCardNumber ?? '';
    balanceController.text = widget.initialCurrentBalance ?? '';
    pinCodeController.text = widget.initialPinCode ?? '';
    noteController.text = widget.initialNote ?? '';

    brandId = widget.initialBrandId ?? '';
    logoAsset = widget.initialLogoAsset ?? '';
    brandColor = widget.initialBrandColor ?? '';
    customImage = widget.initialCustomImage ?? '';

    nameController.addListener(refresh);
    codeController.addListener(refresh);
    balanceController.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    balanceController.dispose();
    pinCodeController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> scanCode() async {
    HapticFeedback.selectionClick();

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const GiftCardScannerScreen(
          showManualAfterDelay: true,
        ),
      ),
    );

    if (!mounted || result == null || result.trim().isEmpty) return;

    setState(() {
      codeController.text = result.trim();
    });
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    HapticFeedback.selectionClick();

    setState(() {
      customImage = image.path;
      logoAsset = '';
      brandColor = '';
      brandId = '';
    });
  }

  void removeLogo() {
    HapticFeedback.selectionClick();

    setState(() {
      customImage = '';
      logoAsset = '';
      brandColor = '';
      brandId = '';
    });
  }

  String normalizeAmount(String value) {
    return value.trim().replaceAll(',', '.');
  }

  void saveGiftCard() {
    final name = nameController.text.trim();
    final code = codeController.text.trim();
    final balance = normalizeAmount(balanceController.text);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Naam is verplicht.'),
        ),
      );
      return;
    }

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcode / kaartnummer is verplicht.'),
        ),
      );
      return;
    }

    final now = DateTime.now().toIso8601String();

    HapticFeedback.mediumImpact();

    Navigator.pop(context, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'Cadeaukaart',
      'name': name,
      'code': code,
      'cardNumber': code,
      'pinCode': pinCodeController.text.trim(),
      'initialBalance': balance,
      'currentBalance': balance,
      'note': noteController.text.trim(),
      'brandId': brandId,
      'logoAsset': logoAsset,
      'brandColor': brandColor,
      'customImage': customImage,
      'isFavorite': 'false',
      'createdAt': now,
      'updatedAt': now,
      'lastUsedAt': '',
      'balanceHistory': '[]',
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = nameController.text.trim().isEmpty
        ? 'Cadeaukaart'
        : nameController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Cadeaukaart bewerken' : 'Cadeaukaart afronden',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF4F4F6),
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: saveGiftCard,
            child: const Text(
              'Opslaan',
              style: TextStyle(
                color: Color(0xFFD51B46),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
        children: [
          _GiftCardLivePreview(
            name: name,
            code: codeController.text.trim(),
            formattedCode: formattedCode,
            barcode: barcodeType,
            balance: balanceController.text.trim(),
            cardColor: cardColor,
            logoAsset: logoAsset,
            customImage: customImage,
          ),

          const SizedBox(height: 16),

          _SectionCard(
            title: 'Wat is het saldo?',
            subtitle: 'Vul het huidige saldo van deze cadeaukaart in.',
            children: [
              _InputField(
                controller: balanceController,
                label: 'Saldo',
                icon: Icons.account_balance_wallet_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 14),
              _InputField(
                controller: pinCodeController,
                label: 'Pincode / krascode (optioneel)',
                icon: Icons.lock_outline_rounded,
                keyboardType: TextInputType.text,
              ),
            ],
          ),

          const SizedBox(height: 14),

          _SectionCard(
            title: 'Kaart',
            children: [
              _InputField(
                controller: nameController,
                label: 'Naam cadeaukaart',
                icon: Icons.card_giftcard_rounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              _InputField(
                controller: codeController,
                label: 'Barcode / kaartnummer',
                icon: Icons.qr_code_scanner_rounded,
                keyboardType: TextInputType.number,
                suffix: IconButton(
                  onPressed: scanCode,
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFFD51B46),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: scanCode,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Cadeaukaart opnieuw scannen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD51B46),
                    side: const BorderSide(
                      color: Color(0xFFD51B46),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _SectionCard(
            title: 'Notitie',
            children: [
              _InputField(
                controller: noteController,
                label: 'Notitie',
                icon: Icons.notes_rounded,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),

          const SizedBox(height: 14),

          _SectionCard(
            title: 'Logo',
            children: [
              _LogoEditor(
                logoAsset: logoAsset,
                customImage: customImage,
                backgroundColor: cardColor,
                onPickImage: pickImage,
                onRemoveImage: removeLogo,
              ),
            ],
          ),

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              onPressed: saveGiftCard,
              icon: const Icon(Icons.save_rounded),
              label: Text(
                widget.isEditing
                    ? 'Wijzigingen opslaan'
                    : 'Cadeaukaart opslaan',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD51B46),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftCardLivePreview extends StatelessWidget {
  final String name;
  final String code;
  final String formattedCode;
  final Barcode barcode;
  final String balance;
  final Color cardColor;
  final String logoAsset;
  final String customImage;

  const _GiftCardLivePreview({
    required this.name,
    required this.code,
    required this.formattedCode,
    required this.barcode,
    required this.balance,
    required this.cardColor,
    required this.logoAsset,
    required this.customImage,
  });

  bool get hasAssetLogo => logoAsset.isNotEmpty;

  bool get hasCustomLogo =>
      customImage.isNotEmpty && File(customImage).existsSync();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            cardColor,
            cardColor.withOpacity(0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          children: [
            Container(
              height: 108,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
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
                      Icons.card_giftcard_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: code.isEmpty
                        ? const SizedBox(
                      height: 86,
                      child: Center(
                        child: Text(
                          'Nog geen barcode',
                          style: TextStyle(
                            color: Colors.black38,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                        : BarcodeWidget(
                      barcode: barcode,
                      data: code,
                      width: double.infinity,
                      height: 86,
                      drawText: false,
                      errorBuilder: (_, __) {
                        return const SizedBox(
                          height: 86,
                          child: Center(
                            child: Text(
                              'Barcode kan niet worden weergegeven',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (code.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      formattedCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F1F24),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8E3EA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      balance.trim().isEmpty ? 'Saldo onbekend' : '€ $balance',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD51B46),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2F2F34),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.black.withOpacity(0.52),
                fontSize: 13.5,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Widget? suffix;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.suffix,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: maxLines > 1 ? TextInputAction.newline : textInputAction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF4F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: Color(0xFFD51B46),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _LogoEditor extends StatelessWidget {
  final String logoAsset;
  final String customImage;
  final Color backgroundColor;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  const _LogoEditor({
    required this.logoAsset,
    required this.customImage,
    required this.backgroundColor,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  bool get hasPresetLogo => logoAsset.isNotEmpty;

  bool get hasCustomLogo =>
      customImage.isNotEmpty && File(customImage).existsSync();

  @override
  Widget build(BuildContext context) {
    final hasLogo = hasPresetLogo || hasCustomLogo;

    return Column(
      children: [
        Container(
          height: 116,
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: hasPresetLogo ? backgroundColor : const Color(0xFFF4F4F6),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: hasCustomLogo
                ? Image.file(File(customImage), fit: BoxFit.contain)
                : hasPresetLogo
                ? Image.asset(logoAsset, fit: BoxFit.contain)
                : const Icon(
              Icons.image_outlined,
              size: 52,
              color: Colors.black38,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickImage,
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(hasLogo ? 'Logo wijzigen' : 'Logo toevoegen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD51B46),
                  side: const BorderSide(
                    color: Color(0xFFD51B46),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (hasLogo) ...[
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                width: 54,
                child: IconButton(
                  onPressed: onRemoveImage,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.08),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}