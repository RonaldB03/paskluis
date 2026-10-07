import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paskluis_v1/data/services/storage_service.dart';
import 'package:paskluis_v1/data/services/settings_service.dart';
import 'package:paskluis_v1/data/services/locale_service.dart';
import 'package:paskluis_v1/data/services/card_share_service.dart';
import 'package:paskluis_v1/features/qr_codes/qr_codes_screen.dart';
import 'package:paskluis_v1/features/gift_cards/gift_card_view_screen.dart';
import 'package:paskluis_v1/l10n/generated/app_localizations.dart';
import 'package:paskluis_v1/l10n/l10n.dart';

Future<int?> seed(WidgetTester tester, Map<String, dynamic> card) =>
    tester.runAsync(() => StorageService.cardsBox.add(card));
Widget app(Widget child) => MaterialApp(
  locale: const Locale('nl'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: child,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
    await LocaleService.init();
    await LocaleService.setLanguage('nl');
    dir = await Directory.systemTemp.createTemp('paskluis-share-');
    Hive.init(dir.path);
    await Hive.openBox(StorageService.cardsBoxName);
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  for (final type in ['QR-code', 'QR-set']) {
    testWidgets(
      '$type long press offers sharing and signed-out users are asked to sign in',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await seed(tester, {
          'id': 'qr',
          'type': type,
          'name': 'Testcode',
          'code': 'abc',
          'codes': 'abc|||def',
          'used': 'false|||false',
        });
        await tester.pumpWidget(app(const QrCodesScreen()));
        await tester.pumpAndSettle();
        await tester.longPress(find.text('Testcode'));
        await tester.pumpAndSettle();
        expect(find.text(L10n.current.share), findsOneWidget);
        await tester.tap(find.text(L10n.current.share));
        await tester.pumpAndSettle();
        expect(find.text(L10n.current.signInRequired), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('received read-only QR cannot be shared onward or edited', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seed(tester, {
      'id': 'qr',
      'type': 'QR-code',
      'name': 'Received',
      'code': 'abc',
      'isShared': true,
      'canEditShared': false,
    });
    await tester.pumpWidget(app(const QrCodesScreen()));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Received'));
    await tester.pumpAndSettle();
    expect(find.text(L10n.current.share), findsNothing);
    expect(find.text(L10n.current.edit), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'revocation without an owner session fails instead of pretending success',
    () async {
      await expectLater(
        CardShareService.revokeAllForCard('shared-owned-card'),
        throwsA(isA<Exception>()),
      );
    },
  );
  testWidgets(
    'an open received QR disappears after revoked access removes the local copy',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final card = <String, dynamic>{
        'id': 'qr',
        'type': 'QR-code',
        'name': 'Received',
        'code': 'abc',
        'isShared': true,
        'canEditShared': false,
      };
      final key = await seed(tester, card);
      await tester.pumpWidget(
        app(QrCodeViewScreen(items: [card], initialIndex: 0)),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => StorageService.cardsBox.delete(key));
      await tester.pumpAndSettle();
      expect(find.text('Received'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'empty gift card offers deletion rather than archiving and actually removes it',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final card = <String, dynamic>{
        'id': 'gift',
        'type': 'Cadeaukaart',
        'name': 'Gift',
        'code': '123456789',
        'currentBalance': '0',
      };
      await seed(tester, card);
      await tester.pumpWidget(
        app(GiftCardViewScreen(items: [card], initialIndex: 0)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(L10n.current.usedThisCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() async {
        await tester.tap(find.text(L10n.current.cardFullyUsed));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (
        var i = 0;
        i < 10 && find.text(L10n.current.delete).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(L10n.current.archive), findsNothing);
      expect(find.text(L10n.current.delete), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text(L10n.current.delete));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(StorageService.cardsBox.length, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
