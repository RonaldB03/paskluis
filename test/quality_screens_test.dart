import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:paskluis_v1/data/services/storage_service.dart';
import 'package:paskluis_v1/features/scanner/smart_add_screen.dart';
import 'package:paskluis_v1/l10n/l10n.dart';

void main() {
  for (final type in SmartAddManualType.values) {
    testWidgets('classic add flow preserves chosen $type', (tester) async {
      SmartAddOutcome? outcome;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        return TextButton(onPressed: () async {
          outcome = await Navigator.push<SmartAddOutcome>(context,
            MaterialPageRoute(builder: (_) => const SmartAddScreen()));
        }, child: const Text('Open'));
      })));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final label = switch (type) {
        SmartAddManualType.loyalty => L10n.current.cardTypeLoyalty,
        SmartAddManualType.qr => L10n.current.qrCode,
        SmartAddManualType.gift => L10n.current.cardTypeGift,
      };
      expect(find.text(L10n.current.importFromScreenshot), findsNothing);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(L10n.current.importFromScreenshot), findsOneWidget);
      await tester.tap(find.text(L10n.current.chooseAnotherType));
      await tester.pumpAndSettle();
      expect(find.text(L10n.current.whatWouldYouLikeToAdd), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(L10n.current.chooseAStoreOrEnterManually));
      await tester.pumpAndSettle();
      expect(outcome?.selectedType, type);
      expect(outcome?.importResult, isNull);
      expect(find.byType(SmartAddScreen), findsNothing);
    });
  }
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('paskluis-screen-test-');
    Hive.init(directory.path);
    await Hive.openBox(StorageService.cardsBoxName);
    await StorageService.cardsBox.addAll([
      {
        'id': 'gift',
        'name': 'Een lange winkelnaam',
        'brandId': 'a',
        'type': 'Cadeaukaart',
        'currentBalance': '23,50',
        'expiryDate': '2026-10-03',
      },
      {
        'id': 'loyalty',
        'name': 'Winkel',
        'brandId': 'a',
        'type': 'Pasje',
        'code': '123',
      },
    ]);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  for (final screen in <Widget>[
    const SmartAddScreen(),
  ]) {
    testWidgets(
      '${screen.runtimeType} remains readable at 300% text on a narrow phone',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 780));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 780),
                textScaler: TextScaler.linear(3),
              ),
              child: screen,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
