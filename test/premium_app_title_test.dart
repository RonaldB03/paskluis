import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/shared/widgets/premium_app_title.dart';
import 'package:paskluis_v1/features/premium/plus_information_screen.dart';

void main() {
  testWidgets('Plus status fits narrow headers with enlarged text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final title in ['PasKluis', 'Klantenkaarten', 'QR-codes', 'Cadeaukaarten']) {
      for (final plus in [false, true]) {
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(appBar: AppBar(
            leadingWidth: 96,
            leading: const Row(children: [Icon(Icons.info), Icon(Icons.language)]),
            titleSpacing: 0,
            title: AppTitleWithPlus(title: title, plus: plus),
            actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.add))],
          )),
        ));
        await tester.pumpAndSettle();
        expect(find.text('PLUS'), plus ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
        if (plus) {
          expect(tester.getSize(find.text('PLUS')).height, greaterThanOrEqualTo(13));
        }
        final titleRect = tester.getRect(find.text(title));
        final settingsRect = tester.getRect(find.byIcon(Icons.settings));
        expect(titleRect.right, lessThan(settingsRect.left));
      }
    }
  });
  testWidgets('Plus badge opens active benefits without purchase offer', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      appBar: AppBar(title: const AppTitleWithPlus(title: 'PasKluis', plus: true)),
    )));
    await tester.tap(find.text('PLUS'));
    await tester.pumpAndSettle();
    expect(find.byType(PlusInformationScreen), findsOneWidget);
    expect(tester.widget<PlusInformationScreen>(find.byType(PlusInformationScreen)).isActive, isTrue);
    expect(find.textContaining('€'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
