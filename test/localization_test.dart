import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paskluis_v1/data/services/locale_service.dart';
import 'package:paskluis_v1/data/services/help_service.dart';
import 'package:paskluis_v1/l10n/generated/app_localizations.dart';
import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:paskluis_v1/shared/widgets/language_picker.dart';
import 'package:paskluis_v1/shared/utils/amount_format.dart';
import 'package:paskluis_v1/features/premium/plus_information_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocaleService.init();
  });

  test('existing preferences preserve Dutch on upgrade', () async {
    SharedPreferences.setMockInitialValues({'favorites_first': true});
    await LocaleService.init();
    expect(LocaleService.preference.value, 'nl');
  });

  test('existing cards preserve Dutch even without preferences', () async {
    SharedPreferences.setMockInitialValues({});
    await LocaleService.init(hasSavedCards: true);
    expect(LocaleService.preference.value, 'nl');
  });

  test('fresh installs follow the phone and unsupported languages use English', () async {
    expect(LocaleService.preference.value, 'system');
    expect(LocaleService.resolve(const Locale('fr', 'FR')).languageCode, 'en');
    expect(LocaleService.resolve(const Locale('nl', 'BE')).languageCode, 'nl');
  });

  test('manual choice survives restart and updates amounts and offline FAQs', () async {
    await LocaleService.setLanguage('en');
    await LocaleService.init();
    expect(LocaleService.preference.value, 'en');
    expect(formatAmountValue('12.50'), '12.50');
    expect(HelpService.fallbackFaqs.first.question, 'How do I add a card?');
    await LocaleService.setLanguage('nl');
    expect(formatAmountValue('12.50'), '12,50');
    expect(HelpService.fallbackFaqs.first.question, 'Hoe voeg ik een kaart toe?');
  });

  test('translation placeholders and keys match between languages', () {
    final nl = jsonDecode(File('lib/l10n/app_nl.arb').readAsStringSync()) as Map;
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    final keys = nl.keys.where((key) => !key.toString().startsWith('@')).toSet();
    expect(en.keys.where((key) => !key.toString().startsWith('@')).toSet(), keys);
    for (final key in keys) {
      final pattern = RegExp(r'\{p\d+\}');
      final declared = (nl['@$key']?['placeholders'] as Map?)?.keys.toSet() ?? <String>{};
      expect(declared, pattern.allMatches(nl[key] as String).map((m) => m[0]!.substring(1,m[0]!.length-1)).toSet(), reason: 'Unused placeholders: $key');
      expect(pattern.allMatches(en[key] as String).map((m) => m[0]).toSet(),
          pattern.allMatches(nl[key] as String).map((m) => m[0]).toSet(), reason: key.toString());
    }
  });

  test('managed English FAQs never substitute Dutch content', () {
    final faq = HelpFaq.fromJson({'id': '1', 'question': 'Vraag', 'answer': 'Antwoord'}, language: 'en');
    expect(faq.question, isEmpty);
    final translated = HelpFaq.fromJson({'question_en': 'Question', 'answer_en': 'Answer'}, language: 'en');
    expect(translated.answer, 'Answer');
  });

  testWidgets('language picker switches an existing screen without restarting', (tester) async {
    await LocaleService.setLanguage('nl');
    await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: LocaleService.locale,
      builder: (_, locale, child) => MaterialApp(
        locale: locale,
        supportedLocales: LocaleService.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const _LanguageTestScreen(),
      ),
    ));
    expect(find.text('Instellingen'), findsOneWidget);
    await tester.tap(find.byType(LanguageButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(LocaleService.preference.value, 'en');
    expect(find.byTooltip('Choose your language'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plus page fits a narrow phone in English with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await LocaleService.setLanguage('en');
    await tester.pumpWidget(MaterialApp(
      locale: LocaleService.locale.value,
      supportedLocales: LocaleService.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: const PlusInformationScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('More freedom. Forever.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _LanguageTestScreen extends StatelessWidget {
  const _LanguageTestScreen();
  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Scaffold(appBar: AppBar(title: Text(L10n.current.settings), actions: const [LanguageButton()]));
  }
}
