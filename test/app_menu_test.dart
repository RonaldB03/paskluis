import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:paskluis_v1/data/services/app_menu_service.dart';
import 'package:paskluis_v1/data/services/settings_service.dart';
import 'package:paskluis_v1/data/services/storage_service.dart';
import 'package:paskluis_v1/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> config() => jsonDecode(File('assets/config/app_menu.json').readAsStringSync()) as Map<String,dynamic>;
  test('default menu is valid and all configurable actions are known', () {
    final menu = AppMenu.parse(config());
    expect(menu, isNotNull);
    expect(menu!.sections.first['id'], 'help');
    expect(menu.shareText('nl'), contains('https://paskluis.com'));
  });
  test('invalid schema, hidden privacy, unknown actions and duplicate IDs are rejected', () {
    final wrongSchema = config()..['schemaVersion'] = 2;
    expect(AppMenu.parse(wrongSchema), isNull);
    final hidden = config(); hidden['sections'][2]['hidden'] = true;
    expect(AppMenu.parse(hidden), isNull);
    final unknown = config(); unknown['sections'][0]['items'][0]['action'] = 'runCode';
    expect(AppMenu.parse(unknown), isNull);
    final duplicate = config(); duplicate['sections'][0]['items'].add(duplicate['sections'][0]['items'][0]);
    expect(AppMenu.parse(duplicate), isNull);
    expect(AppMenu.parse({'schemaVersion':1,'sections':'bad'}), isNull);
  });
  test('unsafe links are rejected', () {
    for (final url in ['javascript:alert(1)', 'http://paskluis.com', 'https://user:secret@paskluis.com', 'https://paskluis.com/ unsafe']) {
      expect(AppMenu.safeUrl(url), isFalse);
    }
    expect(AppMenu.safeUrl('https://paskluis.com/testen?platform=ios'), isTrue);
  });
  test('audience filtering leaves locked previews visible without unlocking a setting', () {
    expect(AppMenu.visible({'audience':'plus'}, false), isFalse);
    expect(AppMenu.visible({'audience':'free'}, true), isFalse);
    expect(AppMenu.visible({'audience':'locked'}, false), isTrue);
    expect(AppMenu.visible({'hidden':true,'audience':'all'}, true), isFalse);
  });
  test('invalid cache falls back; valid cached menu survives offline refresh', () async {
    SharedPreferences.setMockInitialValues({AppMenuService.cacheKey:'{bad'});
    AppMenuService.current = null;
    await AppMenuService.init();
    expect(AppMenuService.current, isNotNull);
    final saved=config(); saved['sections'][0]['title']['nl']='Mijn hulp';
    SharedPreferences.setMockInitialValues({AppMenuService.cacheKey:jsonEncode(saved)});
    AppMenuService.current = null;
    await AppMenuService.init(); await AppMenuService.refresh();
    expect(AppMenuService.current!.sections[0]['title']['nl'], 'Mijn hulp');
  });
  test('distances and ordering persist independently', () async {
    SharedPreferences.setMockInitialValues({}); await SettingsService.init();
    expect(SettingsService.showCardDistances, isTrue);
    expect(SettingsService.nearbyLoyaltyCardsFirst, isFalse);
    await SettingsService.setShowCardDistances(false);
    await SettingsService.setNearbyLoyaltyCardsFirst(true);
    await SettingsService.init();
    expect(SettingsService.showCardDistances, isFalse);
    expect(SettingsService.nearbyLoyaltyCardsFirst, isTrue);
  });

  group('settings layout', () {
    late Directory directory;
    setUp(() async {
      directory=await Directory.systemTemp.createTemp('settings-menu-');
      Hive.init(directory.path); await Hive.openBox(StorageService.cardsBoxName);
      SharedPreferences.setMockInitialValues({}); await SettingsService.init();
      AppMenuService.current=AppMenu.parse(config());
      PackageInfo.setMockInitialValues(appName:'PasKluis',packageName:'nl.paskluis.app',version:'1.5.0',buildNumber:'113',buildSignature:'');
    });
    tearDown(() async { await Hive.close(); await directory.delete(recursive:true); });
    testWidgets('account stays above collapsible categories on a narrow screen with large text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360,780));
      addTearDown(()=>tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(1.8)),child:child!),home:const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Mijn account'),findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.scrollUntilVisible(find.text('Beveiliging en privacy'),300,scrollable:find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Beveiliging en privacy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beveiliging en privacy').hitTestable()); await tester.pumpAndSettle();
      expect(find.text('Privacy en gegevens'), findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.scrollUntilVisible(find.text('Back-up en herstel'),300,scrollable:find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Back-up en herstel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back-up en herstel').hitTestable());await tester.pumpAndSettle();
      expect(find.text('Automatische back-up'), findsOneWidget);
      // ListView may dispose off-screen sections; scroll back before checking
      // that PageStorage preserved the other section's expanded state.
      await tester.scrollUntilVisible(find.text('Beveiliging en privacy'), -300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('Privacy en gegevens'), findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());await tester.pumpAndSettle();
    });
  });
}
