import 'package:flutter/material.dart';

import '../scanner/scanner_screen.dart';

class AddCardScreen extends StatefulWidget {
  final String initialType;
  final String? initialName;
  final String? initialCode;
  final String? initialBrandId;
  final String? initialLogoAsset;
  final String? initialBrandColor;

  const AddCardScreen({
    super.key,
    this.initialType = 'Pasje',
    this.initialName,
    this.initialCode,
    this.initialBrandId,
    this.initialLogoAsset,
    this.initialBrandColor,
  });

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  late String selectedType;

  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final noteController = TextEditingController();

  final cardNumberController = TextEditingController();
  final pinCodeController = TextEditingController();
  final initialBalanceController = TextEditingController();
  final currentBalanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType;
    nameController.text = widget.initialName ?? '';
    codeController.text = widget.initialCode ?? '';
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

  Future<void> scanCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
  mode: selectedType == 'QR-code'
      ? ScannerMode.qr
      : ScannerMode.barcode,
),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        codeController.text = result;
      });
    }
  }

  void saveCard() {
    if (nameController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vul minimaal een naam en code in.')),
      );
      return;
    }

    Navigator.pop(context, {
      'type': selectedType,
      'name': nameController.text.trim(),
      'code': codeController.text.trim(),
      'note': noteController.text.trim(),
      'cardNumber': cardNumberController.text.trim(),
      'pinCode': pinCodeController.text.trim(),
      'initialBalance': initialBalanceController.text.trim(),
      'currentBalance': currentBalanceController.text.trim(),
      'brandId': widget.initialBrandId ?? '',
      'logoAsset': widget.initialLogoAsset ?? '',
      'brandColor': widget.initialBrandColor ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGiftCard = selectedType == 'Cadeaukaart';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF3A3A3C),
        title: Text(
          selectedType == 'Pasje'
              ? 'Klantenkaart toevoegen'
              : selectedType == 'QR-code'
              ? 'QR-code toevoegen'
              : 'Cadeaukaart toevoegen',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Naam',
              hintText: 'Bijv. Albert Heijn',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            decoration: InputDecoration(
              labelText: 'Barcode / QR-code',
              hintText: 'Scan of vul handmatig in',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: scanCode,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: scanCode,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Code scannen'),
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
          if (isGiftCard) ...[
            const SizedBox(height: 24),
            Text(
              'Cadeaukaartgegevens',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
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
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Oorspronkelijk bedrag',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: currentBalanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Resterend saldo',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: saveCard,
            icon: const Icon(Icons.save),
            label: const Text('Opslaan'),
          ),
        ],
      ),
    );
  }
}