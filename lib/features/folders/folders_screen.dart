import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../data/services/card_folders.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/locale_service.dart';
import '../../l10n/l10n.dart';
import '../cards/card_view_screen.dart';
import '../gift_cards/gift_card_view_screen.dart';
import '../qr_codes/qr_codes_screen.dart';

String _t(String nl, String en) => LocaleService.languageCode == 'nl' ? nl : en;

class FoldersButton extends StatelessWidget {
  const FoldersButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _t('Mijn mappen', 'My folders'),
    icon: const Icon(Icons.folder_outlined),
    onPressed: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const FoldersScreen())),
  );
}

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});
  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  String? selected;

  Future<void> editFolder({String? name}) async {
    final saved = await Navigator.push<String>(context,
      MaterialPageRoute(builder: (_) => _FolderEditor(folder: name)));
    if (mounted && saved != null) setState(() => selected = saved);
  }

  Future<void> removeFolder(String name) async {
    final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(_t('Map verwijderen?', 'Delete folder?')),
      content: Text(_t('Je kaarten blijven bewaard in het gewone overzicht.',
        'Your cards stay in the regular overview.')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L10n.current.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(L10n.current.delete)),
      ],
    ));
    if (confirmed != true) return;
    await CardFolders.assign({}, '', replacing: name);
    if (mounted) setState(() => selected = null);
  }

  void openCard(Map card) {
    final item = Map<String, dynamic>.from(card);
    final Widget screen = switch (item['type']) {
      'Cadeaukaart' => GiftCardViewScreen(items: [item], initialIndex: 0),
      'QR-code' || 'QR-set' => QrCodeViewScreen(items: [item], initialIndex: 0),
      _ => CardViewScreen(items: [item], initialIndex: 0),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return ValueListenableBuilder<Box>(valueListenable: StorageService.cardsBox.listenable(),
      builder: (context, box, _) {
        final names = CardFolders.names(box.values);
        final folder = names.contains(selected) ? selected : null;
        final cards = box.values.whereType<Map>().where((c) => CardFolders.name(c) == folder).toList();
        return Scaffold(
          appBar: AppBar(title: Text(folder ?? _t('Mijn mappen', 'My folders')),
            actions: [
              if (folder != null) IconButton(icon: const Icon(Icons.edit_outlined),
                tooltip: L10n.current.edit, onPressed: () => editFolder(name: folder)),
              if (folder != null) IconButton(icon: const Icon(Icons.folder_delete_outlined),
                tooltip: L10n.current.delete, onPressed: () => removeFolder(folder)),
              if (folder == null) IconButton(icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: _t('Nieuwe map', 'New folder'), onPressed: () => editFolder()),
            ]),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (folder == null) ...[
              Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(_t(
                'Mappen zijn optioneel. Je kaarten blijven ook in het gewone overzicht staan. Maak een map door kaarten te kiezen.',
                'Folders are optional. Your cards also stay in the regular overview. Choose cards to create a folder.'))),
              for (final name in names) ListTile(
                leading: const Icon(Icons.folder_outlined), title: Text(name),
                subtitle: Text('${box.values.whereType<Map>().where((c) => CardFolders.name(c) == name).length} ${_t('kaarten', 'cards')}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => selected = name)),
              if (names.isEmpty) FilledButton.icon(onPressed: () => editFolder(),
                icon: const Icon(Icons.create_new_folder_outlined), label: Text(_t('Maak je eerste map', 'Create your first folder'))),
            ] else ...[
              TextButton.icon(onPressed: () => setState(() => selected = null),
                icon: const Icon(Icons.arrow_back), label: Text(_t('Alle mappen', 'All folders'))),
              for (final card in cards) ListTile(
                leading: Icon(card['type'] == 'Cadeaukaart' ? Icons.redeem : Icons.credit_card),
                title: Text(card['name']?.toString() ?? ''),
                subtitle: Text(L10n.cardType(card['type']?.toString())),
                trailing: const Icon(Icons.chevron_right), onTap: () => openCard(card)),
            ],
          ]),
        );
      });
  }
}

class _FolderEditor extends StatefulWidget {
  final String? folder;
  const _FolderEditor({this.folder});
  @override
  State<_FolderEditor> createState() => _FolderEditorState();
}

class _FolderEditorState extends State<_FolderEditor> {
  late final TextEditingController name = TextEditingController(text: widget.folder ?? '');
  late final int revision;
  final Set<dynamic> selected = {};
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    revision = StorageService.accountRevision;
    if (widget.folder != null) {
      for (final key in StorageService.cardsBox.keys) {
        final card = StorageService.cardsBox.get(key);
        if (card is Map && CardFolders.name(card) == widget.folder) selected.add(key);
      }
    }
  }
  @override
  void dispose() { name.dispose(); super.dispose(); }

  Future<void> save() async {
    if (saving) return;
    final value = name.text.trim();
    final names = CardFolders.names(StorageService.cardsBox.values);
    if (value.isEmpty || value.length > 60 || selected.isEmpty) {
      setState(() => error = _t('Vul een mapnaam in en kies minstens één kaart.', 'Enter a folder name and select at least one card.'));
      return;
    }
    if (names.any((n) => n != widget.folder && n.toLowerCase() == value.toLowerCase())) {
      setState(() => error = _t('Er bestaat al een map met deze naam.', 'A folder with this name already exists.'));
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      if (revision != StorageService.accountRevision) throw StateError('Account changed');
      await CardFolders.assign(selected, value, replacing: widget.folder);
      if (mounted) Navigator.pop(context, value);
    } catch (_) {
      if (mounted) setState(() { saving = false; error = _t('Opslaan mislukt. Probeer opnieuw.', 'Saving failed. Try again.'); });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.folder == null ? _t('Nieuwe map', 'New folder') : _t('Map bewerken', 'Edit folder'))),
    body: ValueListenableBuilder<Box>(valueListenable: StorageService.cardsBox.listenable(), builder: (context, box, _) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, maxLength: 60, enabled: !saving,
          decoration: InputDecoration(labelText: _t('Mapnaam', 'Folder name'), errorText: error)),
        Text(_t('Kies kaarten. Een kaart kan in één map staan. Een lege map verdwijnt automatisch.',
          'Select cards. A card can belong to one folder. Empty folders disappear automatically.')),
        for (final key in box.keys)
          if (box.get(key) is Map) CheckboxListTile(
            title: Text((box.get(key) as Map)['name']?.toString() ?? ''),
            subtitle: Text(CardFolders.name(box.get(key) as Map)),
            value: selected.contains(key),
            onChanged: saving ? null : (checked) => setState(() { checked == true ? selected.add(key) : selected.remove(key); })),
        const SizedBox(height: 16),
        FilledButton(onPressed: saving ? null : save,
          child: Text(saving ? _t('Opslaan…', 'Saving…') : L10n.current.save)),
      ])),
  );
}
