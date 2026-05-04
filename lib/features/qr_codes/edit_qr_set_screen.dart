import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'qr_scanner_screen.dart';

class EditQrSetScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditQrSetScreen({
    super.key,
    required this.item,
  });

  @override
  State<EditQrSetScreen> createState() => _EditQrSetScreenState();
}

class _EditQrSetScreenState extends State<EditQrSetScreen> {
  final nameController = TextEditingController();
  final noteController = TextEditingController();

  late List<String> codes;
  late List<bool> used;

  @override
  void initState() {
    super.initState();

    nameController.text = widget.item['name']?.toString() ?? 'QR-codes';
    noteController.text = widget.item['note']?.toString() ?? '';

    codes = (widget.item['codes']?.toString() ?? '')
        .split('|||')
        .where((code) => code.trim().isNotEmpty)
        .toList();

    final rawUsed = widget.item['used']?.toString() ?? '';

    used = rawUsed.isEmpty
        ? List.filled(codes.length, false)
        : rawUsed.split('|||').map((value) => value == 'true').toList();

    while (used.length < codes.length) {
      used.add(false);
    }

    if (used.length > codes.length) {
      used = used.take(codes.length).toList();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> addQrCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(),
      ),
    );

    if (!mounted || result == null || result.trim().isEmpty) return;

    final code = result.trim();

    if (codes.contains(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deze QR-code staat al in deze set.'),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      codes.add(code);
      used.add(false);
    });
  }

  Future<void> replaceQrCode(int index) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(),
      ),
    );

    if (!mounted || result == null || result.trim().isEmpty) return;

    final code = result.trim();

    final alreadyExists = codes.asMap().entries.any(
          (entry) => entry.key != index && entry.value == code,
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deze QR-code staat al in deze set.'),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      codes[index] = code;
      used[index] = false;
    });
  }

  void removeQrCode(int index) {
    if (codes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Een QR-set moet minimaal 1 QR-code bevatten.'),
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      codes.removeAt(index);
      used.removeAt(index);
    });
  }

  void toggleUsed(int index) {
    HapticFeedback.selectionClick();

    setState(() {
      used[index] = !used[index];
    });
  }

  void save() {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Naam is verplicht.'),
        ),
      );
      return;
    }

    if (codes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voeg minimaal 1 QR-code toe.'),
        ),
      );
      return;
    }

    final updated = Map<String, dynamic>.from(widget.item);

    updated['type'] = 'QR-set';
    updated['name'] = name;
    updated['note'] = noteController.text.trim();
    updated['codes'] = codes.join('|||');
    updated['used'] = used.map((value) => value ? 'true' : 'false').join('|||');
    updated['updatedAt'] = DateTime.now().toIso8601String();

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final usedCount = used.where((value) => value == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text(
          'QR-set bewerken',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF4F4F6),
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
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
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
        children: [
          _SectionCard(
            title: 'Setgegevens',
            subtitle: '$usedCount van ${codes.length} QR-codes gebruikt',
            children: [
              _InputField(
                controller: nameController,
                label: 'Naam QR-set',
                icon: Icons.confirmation_number_rounded,
              ),
              const SizedBox(height: 14),
              _InputField(
                controller: noteController,
                label: 'Notitie',
                icon: Icons.notes_rounded,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'QR-codes',
            subtitle: 'Beheer de tickets binnen deze set.',
            children: [
              ...List.generate(codes.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == codes.length - 1 ? 0 : 12,
                  ),
                  child: _QrSetItemTile(
                    index: index,
                    code: codes[index],
                    isUsed: used[index],
                    onToggleUsed: () => toggleUsed(index),
                    onReplace: () => replaceQrCode(index),
                    onRemove: () => removeQrCode(index),
                  ),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: addQrCode,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('QR-code toevoegen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD51B46),
                    side: const BorderSide(
                      color: Color(0xFFD51B46),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
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

class _QrSetItemTile extends StatelessWidget {
  final int index;
  final String code;
  final bool isUsed;
  final VoidCallback onToggleUsed;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  const _QrSetItemTile({
    required this.index,
    required this.code,
    required this.isUsed,
    required this.onToggleUsed,
    required this.onReplace,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 78,
                height: 78,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: QrImageView(
                  data: code,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                ),
              ),
              if (isUsed)
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFFD51B46),
                      size: 34,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ticket ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isUsed ? 'Gebruikt' : 'Niet gebruikt',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isUsed
                        ? const Color(0xFFD51B46)
                        : Colors.black.withOpacity(0.52),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.black.withOpacity(0.46),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'used') onToggleUsed();
              if (value == 'replace') onReplace();
              if (value == 'remove') onRemove();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'used',
                child: Text(isUsed ? 'Markeer als niet gebruikt' : 'Markeer als gebruikt'),
              ),
              const PopupMenuItem(
                value: 'replace',
                child: Text('Opnieuw scannen'),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Text('Verwijderen'),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
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
  final int maxLines;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
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