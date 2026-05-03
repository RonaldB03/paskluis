import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/templates/card_templates.dart';
import '../scanner/scanner_screen.dart';

class AddGiftCardScreen extends StatefulWidget {
  const AddGiftCardScreen({super.key});

  @override
  State<AddGiftCardScreen> createState() => _AddGiftCardScreenState();
}

class _AddGiftCardScreenState extends State<AddGiftCardScreen> {
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final noteController = TextEditingController();

  final cardNumberController = TextEditingController();
  final pinCodeController = TextEditingController();
  final initialBalanceController = TextEditingController();
  final currentBalanceController = TextEditingController();

  String searchQuery = '';
  String brandId = '';
  String logoAsset = '';
  String brandColor = '';
  File? customImage;

  bool get hasSelectedBrand => logoAsset.isNotEmpty;
  bool get hasCustomImage => customImage != null;

  Color get selectedBrandColor {
    final parsed = int.tryParse(brandColor);
    if (parsed != null) return Color(parsed);
    return Colors.white;
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    noteController.dispose();
    cardNumberController.dispose();
    pinCodeController.dispose();
    initialBalanceController.dispose();
    currentBalanceController.dispose();
    super.dispose();
  }

  void selectBrand(CardBrandTemplate brand) {
    setState(() {
      brandId = brand.id;
      logoAsset = brand.logoAsset;
      brandColor = brand.color.value.toString();
      nameController.text = '${brand.name} cadeaukaart';
      customImage = null;
    });
  }

  void clearBrand() {
    setState(() {
      brandId = '';
      logoAsset = '';
      brandColor = '';
    });
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() {
      customImage = File(image.path);
      brandId = '';
      logoAsset = '';
      brandColor = '';
    });
  }

  Future<void> scanCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(
          mode: ScannerMode.barcode,
          showManualAfterDelay: true,
        ),
      ),
    );

    if (result == null || result.isEmpty) return;

    if (result == ScannerScreen.manualEntryResult) return;

    setState(() {
      codeController.text = result;
    });
  }

  void saveGiftCard() {
    if (nameController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vul minimaal een naam en barcode in.'),
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'type': 'Cadeaukaart',
      'name': nameController.text.trim(),
      'code': codeController.text.trim(),
      'note': noteController.text.trim(),
      'cardNumber': cardNumberController.text.trim(),
      'pinCode': pinCodeController.text.trim(),
      'initialBalance': initialBalanceController.text.trim(),
      'currentBalance': currentBalanceController.text.trim(),
      'brandId': brandId,
      'logoAsset': logoAsset,
      'brandColor': brandColor,
      'customImage': customImage?.path ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredBrands = cardBrandTemplates.where((brand) {
      return brand.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text(
          'Cadeaukaart toevoegen',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: saveGiftCard,
            child: const Text(
              'Opslaan',
              style: TextStyle(
                color: Color(0xFFD51B46),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Kies een winkel',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Zoek winkel of merk',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),

          if (!hasSelectedBrand && !hasCustomImage)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredBrands.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.65,
              ),
              itemBuilder: (context, index) {
                final brand = filteredBrands[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => selectBrand(brand),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: brand.color,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Image.asset(
                        brand.logoAsset,
                        fit: BoxFit.contain,
                        height: 74,
                        width: double.infinity,
                      ),
                    ),
                  ),
                );
              },
            ),

          if (hasSelectedBrand || hasCustomImage) ...[
            Container(
              height: 125,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: hasSelectedBrand ? selectedBrandColor : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Center(
                child: hasCustomImage
                    ? Image.file(
                  customImage!,
                  fit: BoxFit.contain,
                  height: 90,
                  width: double.infinity,
                )
                    : Image.asset(
                  logoAsset,
                  fit: BoxFit.contain,
                  height: 90,
                  width: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  customImage = null;
                  clearBrand();
                });
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Andere winkel kiezen'),
            ),
          ],

          const SizedBox(height: 18),

          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: pickImage,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFF8E3EA),
                    child: Icon(
                      Icons.image_outlined,
                      color: Color(0xFFD51B46),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Eigen logo toevoegen',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Naam cadeaukaart',
              hintText: 'Bijv. HEMA cadeaukaart',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: codeController,
            decoration: InputDecoration(
              labelText: 'Barcode',
              hintText: 'Scan of vul handmatig in',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: scanCode,
                icon: const Icon(Icons.qr_code_scanner),
              ),
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: scanCode,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Barcode scannen'),
          ),

          const SizedBox(height: 24),

          const Text(
            'Cadeaukaartgegevens',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF333333),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: cardNumberController,
            decoration: const InputDecoration(
              labelText: 'Kaartnummer',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: pinCodeController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Pincode / krascode',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: initialBalanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Oorspronkelijk saldo',
              prefixText: '€ ',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: currentBalanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Huidig saldo',
              prefixText: '€ ',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notitie',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 28),

          FilledButton.icon(
            onPressed: saveGiftCard,
            icon: const Icon(Icons.save),
            label: const Text('Cadeaukaart opslaan'),
          ),
        ],
      ),
    );
  }
}