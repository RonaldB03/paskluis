import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paskluis_v1/data/services/terms_service.dart';
import 'package:paskluis_v1/data/services/terms_document.dart';
import 'package:paskluis_v1/features/legal/terms_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TermsService.init();
  });
  test('bundled document matches archived receipt identity', () async {
    final raw = await rootBundle.loadString('assets/config/terms.json');
    expect(sha256.convert(utf8.encode(raw)).toString(), TermsDocument.sha256);
    expect(jsonDecode(raw)['version'], TermsDocument.version);
  });
  test('guest acceptance persists and is never attributed to another account', () async {
    expect(TermsService.accepted, isFalse);
    await TermsService.accept('guest', 'nl');
    await TermsService.init();
    expect(TermsService.accepted, isTrue);
    expect(TermsService.receiptFor('another-user'), isNull);
    await expectLater(TermsService.accept('another-user', 'nl'), throwsStateError);
  });
  testWidgets('explicit checkbox is required, then navigation is available', (tester) async {
    // Asset I/O runs outside Flutter's fake clock before exercising the UI.
    await tester.runAsync(() => rootBundle.loadString('assets/config/terms.json'));
    // Same builder position as the real app: outside the root Navigator.
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => TermsGate(child: child!),
      home: const Scaffold(body: Text('Vault')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Vault'), findsNothing);
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 600,
      scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Vault'), findsOneWidget);
    expect(TermsService.accepted, isTrue);
    expect(tester.takeException(), isNull);
  });
}
