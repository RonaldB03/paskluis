import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/shared/widgets/home_section_prompt.dart';
import 'package:paskluis_v1/features/scanner/scanner_screen.dart';
import 'package:paskluis_v1/l10n/l10n.dart';

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('location prompt stays readable at text scale $scale', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(
          width: 320,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SingleChildScrollView(child: HomeSectionPrompt(
              icon: Icons.near_me_outlined,
              title: 'Toon kaarten die je hier gebruikt',
              subtitle: 'Je locatie blijft op je telefoon.',
              actionLabel: 'Locatie gebruiken',
              onAction: () {},
            )),
          ),
        ))),
      ));
      final title = find.text('Toon kaarten die je hier gebruikt');
      expect(tester.getSize(title).width, greaterThan(200));
      expect(tester.getTopLeft(find.text('Locatie gebruiken')).dy,
          greaterThan(tester.getBottomLeft(find.text('Je locatie blijft op je telefoon.')).dy));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('manual entry is distinct from scanning and dismissing', (tester) async {
    var manual = false;
    ScannerMode? mode;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          mode = await showCodeTypeDialog(context, onManualEntry: () => manual = true);
        },
        child: const Text('Open'),
      ),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(L10n.current.enterBarcodeManually));
    await tester.tap(find.text(L10n.current.enterBarcodeManually));
    await tester.pumpAndSettle();
    expect(manual, isTrue);
    expect(mode, isNull);
    expect(find.byType(ScannerScreen), findsNothing);
  });
}
