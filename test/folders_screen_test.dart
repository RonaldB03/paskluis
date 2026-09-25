import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:paskluis_v1/data/services/storage_service.dart';
import 'package:paskluis_v1/features/folders/folders_screen.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('folder-ui-');
    Hive.init(dir.path); await Hive.openBox(StorageService.cardsBoxName);
    await StorageService.addCard({'id': 'a', 'name': 'Test shop', 'type': 'Pasje'});
  });
  tearDown(() async { await Hive.close(); await dir.delete(recursive: true); });
  testWidgets('optional folder creation works on a narrow screen with enlarged text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)), child: child!),
      home: const FoldersScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.create_new_folder_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Family');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.runAsync(() async {
      final saved = StorageService.cardsBox.watch().firstWhere((event) =>
        event.value is Map && (event.value as Map)['folderName'] == 'Family');
      await tester.tap(find.byType(FilledButton));
      await saved.timeout(const Duration(seconds: 5));
      await StorageService.cardsBox.flush();
    });
    await tester.pumpAndSettle();
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Test shop'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
