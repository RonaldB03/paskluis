import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../scanner/scanner_screen.dart';

class EditCardScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditCardScreen({
    super.key,
    required this.item,
  });

  @override
  State<EditCardScreen> createState() => _EditCardScreenState();
}

class _EditCardScreenState extends State<EditCardScreen> {
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final noteController = TextEditingController();

  String logoAsset = '';
  String brandColor = '';
  String customImage = '';

  bool get hasPresetLogo => logoAsset.isNotEmpty;

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

    nameController.text = widget.item['name']?.toString() ?? '';
    codeController.text = widget.item['code']?.toString() ?? '';
    noteController.text = widget.item['note']?.toString() ?? '';

    logoAsset = widget.item['logoAsset']?.toString() ?? '';
    brandColor = widget.item['brandColor']?.toString() ?? '';
    customImage = widget.item['customImage']?.toString() ?? '';

    codeController.addListener(() {
      if (mounted) setState(() {});
    });

    nameController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    noteController.dispose();
    super.dispose();
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
    });
  }

  void removeLogo() {
    HapticFeedback.selectionClick();

    setState(() {
      customImage = '';
      logoAsset = '';
      brandColor = '';
    });
  }

  Future<void> scanCode() async {
    HapticFeedback.selectionClick();

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(
          mode: ScannerMode.barcode,
          showManualAfterDelay: true,
        ),
      ),
    );

    if (!mounted || result == null || result.trim().isEmpty) return;
    if (result == ScannerScreen.manualEntryResult) return;

    setState(() {
      codeController.text = result.trim();
    });
  }

  void save() {
    final name = nameController.text.trim();
    final code = codeController.text.trim();

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
          content: Text('Barcode is verplicht.'),
        ),
      );
      return;
    }

    final updated = Map<String, dynamic>.from(widget.item);

    updated['type'] = 'Pasje';
    updated['name'] = name;
    updated['code'] = code;
    updated['note'] = noteController.text.trim();

    updated['cardNumber'] = '';
    updated['pinCode'] = '';
    updated['initialBalance'] = '';
    updated['currentBalance'] = '';

    updated['logoAsset'] = logoAsset;
    updated['brandColor'] = brandColor;
    updated['customImage'] = customImage;
    updated['updatedAt'] = DateTime.now().toIso8601String();

    HapticFeedback.mediumImpact();
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final name = nameController.text.trim().isEmpty
        ? 'Klantenkaart'
        : nameController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4F6),
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF2F2F34),
        title: const Text(
          'Kaart bewerken',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: save,
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          _LiveCardPreview(
            name: name,
            code: codeController.text.trim(),
            formattedCode: formattedCode,
            barcode: barcodeType,
            cardColor: cardColor,
            logoAsset: logoAsset,
            customImage: customImage,
          ),

          const SizedBox(height: 20),

          _SectionCard(
            title: 'Kaartgegevens',
            children: [
              _InputField(
                controller: nameController,
                label: 'Naam',
                icon: Icons.badge_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              _InputField(
                controller: codeController,
                label: 'Barcode',
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
                  label: const Text('Barcode opnieuw scannen'),
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

          const SizedBox(height: 14),

          _SectionCard(
            title: 'Notitie',
            children: [
              _InputField(
                controller: noteController,
                label: 'Notitie toevoegen',
                icon: Icons.notes_rounded,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Wijzigingen opslaan'),
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

class _LiveCardPreview extends StatelessWidget {
  final String name;
  final String code;
  final String formattedCode;
  final Barcode barcode;
  final Color cardColor;
  final String logoAsset;
  final String customImage;

  const _LiveCardPreview({
    required this.name,
    required this.code,
    required this.formattedCode,
    required this.barcode,
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
              height: 118,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
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
                      size: 54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
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
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: code.isEmpty
                        ? const SizedBox(
                      height: 94,
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
                      height: 94,
                      drawText: false,
                      errorBuilder: (_, __) {
                        return const SizedBox(
                          height: 94,
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
                    const SizedBox(height: 14),
                    Text(
                      formattedCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        letterSpacing: 1.6,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F1F24),
                      ),
                    ),
                  ],
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
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
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
        enabledBorder: OutlineInputBorder(
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
          height: 120,
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: hasPresetLogo ? backgroundColor : const Color(0xFFF4F4F6),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.black.withOpacity(0.05),
            ),
          ),
          child: Center(
            child: hasCustomLogo
                ? Image.file(
              File(customImage),
              fit: BoxFit.contain,
            )
                : hasPresetLogo
                ? Image.asset(
              logoAsset,
              fit: BoxFit.contain,
            )
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