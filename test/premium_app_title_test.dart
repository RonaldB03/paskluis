import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/shared/widgets/premium_app_title.dart';

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
        final titleRect = tester.getRect(find.text(title));
        final settingsRect = tester.getRect(find.byIcon(Icons.settings));
        expect(titleRect.right, lessThan(settingsRect.left));
      }
    }
  });
}
