import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/shared/widgets/main_tab_route.dart';
import 'package:paskluis_v1/shared/widgets/main_tab_swipe_region.dart';

void main() {
  for (final forward in [true, false]) {
    testWidgets('Tab bar stays fixed during a ${forward ? 'forward' : 'backward'} swipe',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      Widget page(String name, int index, ValueChanged<int> switchTab) {
        return Scaffold(
          body: MainTabSwipeRegion(
            currentIndex: index,
            onSwitch: switchTab,
            child: SizedBox.expand(key: ValueKey('body-$name')),
          ),
          bottomNavigationBar: SizedBox(
            key: ValueKey('nav-$name'),
            height: 78,
            child: const Text('Home / Cards / QR / Gifts'),
          ),
        );
      }

      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: page('old', forward ? 1 : 2, (index) {
          expect(index, forward ? 2 : 1);
          navigatorKey.currentState!.pushAndRemoveUntil(
            mainTabRoute(
              page('new', index, (_) {}),
              forward: forward,
            ),
            (_) => false,
          );
        }),
      ));
      final originalNav = tester.getRect(find.byKey(const ValueKey('nav-old')));
      final originalBody = tester.getRect(find.byKey(const ValueKey('body-old')));

      await tester.fling(
        find.byKey(const ValueKey('body-old')),
        Offset(forward ? -350 : 350, 0),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(tester.getRect(find.byKey(const ValueKey('nav-new'))), originalNav);
      final animatedBody = tester.getRect(find.byKey(const ValueKey('body-new')));
      expect(animatedBody.top, originalBody.top);
      expect(animatedBody.left,
          forward ? greaterThan(originalBody.left) : lessThan(originalBody.left));

      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const ValueKey('nav-new'))), originalNav);
      expect(tester.getRect(find.byKey(const ValueKey('body-new'))), originalBody);
      expect(tester.takeException(), isNull);
    });
  }
}
