import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:paskluis_v1/data/services/account_service.dart';
import 'package:paskluis_v1/data/services/purchase_service.dart';
import 'package:paskluis_v1/data/services/store_access_service.dart';
import 'package:paskluis_v1/features/premium/purchase_controls.dart';
import 'fixtures/fake_purchase_platform.dart';

void main() {
  test('offline access expires and clock rollback cannot extend it', () {
    final now = DateTime.utc(2026, 10, 5);
    Map<String,dynamic> row(DateTime date, {bool active=true}) => {'active':active,'verifiedAt':date.toIso8601String()};
    expect(StoreAccessService.cacheIsActive(row(now.subtract(const Duration(days:6))), now), isTrue);
    expect(StoreAccessService.cacheIsActive(row(now.subtract(const Duration(days:7))), now), isFalse);
    expect(StoreAccessService.cacheIsActive(row(now.add(const Duration(minutes:1))), now), isFalse);
    expect(StoreAccessService.cacheIsActive(row(now, active:false), now), isFalse);
    expect(StoreAccessService.cacheIsActive({'active':true}, now), isFalse);
  });
  test('restore reaches store without a PasKluis user', () async {
    final store = InAppPurchasePlatform.instance as FakePurchasePlatform;
    expect(AccountService.currentUser, isNull);
    final before = store.restores;
    await PurchaseService.restore();
    expect(store.restores, before + 1);
    expect(PurchaseService.busy, isFalse);
    expect(PurchaseService.messageCode, 'restoreRequested');
  });
  testWidgets('unavailable store never advertises a made-up price', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PurchaseControls(gold:true))));
    await tester.pumpAndSettle();
    expect(find.textContaining('€'), findsNothing);
    expect(find.byIcon(Icons.restore), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
