import 'package:flutter/widgets.dart';
import 'package:paskluis_v1/data/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paskluis_v1/data/services/settings_service.dart';
import 'package:paskluis_v1/data/services/locale_service.dart';
import 'package:paskluis_v1/data/services/gift_store_reminder_service.dart';
import 'package:paskluis_v1/data/services/nearby_store_service.dart';
import 'package:paskluis_v1/shared/utils/card_sorting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('background region wake never requests a fresh device location', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    final result = await LocationService.resolve(requestPermission: true);
    expect(result.state, LocationAccessState.unavailable);
    expect(result.location, isNull);
  });
  final now = DateTime(2026, 10, 7, 14);
  Map<String, dynamic> card(String id) => {
    'id': id,
    'name': 'Intertoys cadeaukaart',
    'type': 'Cadeaukaart',
    'currentBalance': '25,50',
    'code': 'PRIVATE',
    'pinCode': 'SECRET',
  };
  const match = NearbyStoreMatch(
    distanceMeters: 50,
    storeName: 'Intertoys',
    address: 'Test',
    latitude: 52,
    longitude: 5,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
    await LocaleService.init();
  });
  test(
    'store notifications require opt-in independently of expiry reminders',
    () async {
      expect(SettingsService.nearbyGiftNotificationsEnabled, false);
      await SettingsService.setNearbyGiftNotificationsEnabled(true);
      await SettingsService.setNearbyGiftShowAmount(false);
      await SettingsService.init();
      expect(SettingsService.nearbyGiftNotificationsEnabled, true);
      expect(SettingsService.nearbyGiftShowAmount, false);
    },
  );
  test(
    'expired, archived and empty cards never become reminders; expiry day is inclusive',
    () {
      final c = card('1');
      expect(giftCardCanRemind({...c, 'expiryDate': '2026-10-07'}, now), true);
      for (final patch in [
        {'expiryDate': '2026-10-06'},
        {'isArchived': true},
        {'isArchived': 'true'},
        {'currentBalance': '0'},
        {'currentBalance': 'invalid'},
      ]) {
        expect(giftCardCanRemind({...c, ...patch}, now), false);
      }
    },
  );
  test('one payload per store, no card secrets, and amount can be hidden', () {
    final rows = buildGiftStoreReminders(
      [card('1'), card('2')],
      {'1': match, '2': match},
      now: now,
      showAmount: false,
    );
    expect(rows, hasLength(1));
    expect(rows.single.toString(), isNot(contains('SECRET')));
    expect(rows.single.toString(), isNot(contains('PRIVATE')));
    expect(rows.single['body'].toString(), isNot(contains('25')));
    expect(rows.single['radius'], 100.0);
    final amount = buildGiftStoreReminders(
      [card('1')],
      {'1': match},
      now: now,
      showAmount: true,
    ).single;
    expect(amount['body'].toString(), contains('25'));
    expect(
      amount['validUntil'],
      now.add(const Duration(days: 7)).millisecondsSinceEpoch / 1000,
    );
  });
  test('unknown coordinates are skipped, nearest twenty are bounded', () {
    final cards = List.generate(25, (i) => card('$i'));
    final matches = {
      for (var i = 0; i < 25; i++)
        '$i': NearbyStoreMatch(
          distanceMeters: i.toDouble(),
          storeName: 'Store',
          address: '',
          latitude: 52 + i / 1000,
          longitude: 5,
        ),
    };
    expect(
      buildGiftStoreReminders(cards, matches, now: now, showAmount: true),
      hasLength(20),
    );
    expect(
      buildGiftStoreReminders(
        [card('x')],
        {
          'x': const NearbyStoreMatch(
            distanceMeters: 1,
            storeName: 'Store',
            address: '',
          ),
        },
        now: now,
        showAmount: true,
      ),
      isEmpty,
    );
  });
  test('nearby gift cards precede favorites, outside radius does not', () {
    final cards = [
      {...card('favorite'), 'isFavorite': true},
      card('near'),
      card('far'),
    ];
    final result = sortLoyaltyCards(
      cards,
      favoritesFirst: true,
      sortOrder: 'recent',
      cardType: 'Cadeaukaart',
      nearbyFirst: true,
      nearbyRadiusMeters: 100,
      distances: {'near': 99, 'far': 101},
    );
    expect(result.map((c) => c['id']), ['near', 'favorite', 'far']);
    final disabled = sortLoyaltyCards(
      cards,
      favoritesFirst: true,
      sortOrder: 'recent',
      cardType: 'Cadeaukaart',
      nearbyFirst: false,
      distances: {'near': 1},
    );
    expect(disabled.first['id'], 'favorite');
  });
}
