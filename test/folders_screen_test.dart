import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:paskluis_v1/data/services/storage_service.dart';
import 'package:paskluis_v1/features/folders/folders_screen.dart';

class _FolderNavigationObserver extends NavigatorObserver {
  final saved = Completer<void>();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!saved.isCompleted) saved.complete();
    super.didPop(route, previousRoute);
  }
}

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
    final navigation = _FolderNavigationObserver();
    await tester.pumpWidget(MaterialApp(navigatorObservers: [navigation], builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)), child: child!),
      home: const FoldersScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.create_new_folder_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Family');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    // Hive completes real I/O while Flutter navigation schedules fake-zone
    // microtasks. Advance both until the actual save closes the editor.
    for (var attempt = 0; attempt < 100 && !navigation.saved.isCompleted; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(navigation.saved.isCompleted, isTrue, reason: 'Saving must close the folder editor');
    await tester.pumpAndSettle();
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Test shop'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
