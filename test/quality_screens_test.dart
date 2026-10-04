import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:paskluis_v1/data/services/storage_service.dart';
import 'package:paskluis_v1/features/gift_cards/credit_watch_screen.dart';
import 'package:paskluis_v1/features/scanner/smart_add_screen.dart';
import 'package:paskluis_v1/features/scanner/batch_import_screen.dart';

void main() {
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
    const CreditWatchScreen(),
    const SmartAddScreen(),
    const BatchImportScreen(),
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
