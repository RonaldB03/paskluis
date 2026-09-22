import 'package:flutter/material.dart';
import '../../data/services/locale_service.dart';
import '../../l10n/l10n.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.preference,
      builder: (context, _, child) => IconButton(
        tooltip: L10n.current.chooseLanguage,
        onPressed: () => showLanguagePicker(context),
        icon: Text(LocaleService.flag, style: const TextStyle(fontSize: 23)),
      ),
    );
  }
}

Future<void> showLanguagePicker(BuildContext context) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(L10n.current.chooseLanguage,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
            const SizedBox(height: 8),
            Text(L10n.current.languageDescription),
            const SizedBox(height: 18),
            for (final option in [
              ('system', '🌐', L10n.current.followPhoneLanguage),
              ('nl', '🇳🇱', 'Nederlands'),
              ('en', '🇬🇧', 'English'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(option.$2, style: const TextStyle(fontSize: 28)),
                title: Text(option.$3, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: option.$1 == 'system' ? Text(L10n.current.phoneLanguageHint) : null,
                trailing: LocaleService.preference.value == option.$1
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFFD51B46)) : null,
                selected: LocaleService.preference.value == option.$1,
                onTap: () => Navigator.pop(context, option.$1),
              ),
          ],
        ),
      ),
    ),
  );
  if (selected != null) await LocaleService.setLanguage(selected);
}
