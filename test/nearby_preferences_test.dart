import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paskluis_v1/data/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.init();
  });

  test('existing users retain Home nearby, sorting starts opt-in', () {
    expect(SettingsService.showNearbySection, isTrue);
    expect(SettingsService.nearbyLoyaltyCardsFirst, isFalse);
  });

  test('Home visibility and nearest-first persist independently', () async {
    await SettingsService.setNearbyLoyaltyCardsFirst(true);
    await SettingsService.setShowNearbySection(false);
    await SettingsService.init();
    expect(SettingsService.showNearbySection, isFalse);
    expect(SettingsService.nearbyLoyaltyCardsFirst, isTrue);
    expect(SettingsService.locationCardsEnabled, isTrue);
    await SettingsService.setLocationCardsEnabled(false);
    expect(SettingsService.locationCardsEnabled, isFalse);
    await SettingsService.setLocationCardsEnabled(true);
    expect(SettingsService.showNearbySection, isFalse);
    expect(SettingsService.nearbyLoyaltyCardsFirst, isTrue);
  });

  test('enabling location selects nearest-first but respects later opt-out', () async {
    await SettingsService.setLocationCardsEnabled(false);
    await SettingsService.setNearbyLoyaltyCardsFirst(false);
    await SettingsService.setLocationCardsEnabled(true);
    expect(SettingsService.nearbyLoyaltyCardsFirst, isTrue);

    await SettingsService.setNearbyLoyaltyCardsFirst(false);
    await SettingsService.setLocationCardsEnabled(true);
    await SettingsService.init();
    expect(SettingsService.locationCardsEnabled, isTrue);
    expect(SettingsService.nearbyLoyaltyCardsFirst, isFalse);

    await SettingsService.setLocationCardsEnabled(false);
    await SettingsService.setLocationCardsEnabled(true);
    expect(SettingsService.nearbyLoyaltyCardsFirst, isTrue);
  });
}
