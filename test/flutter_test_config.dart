import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'fixtures/fake_purchase_platform.dart';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Initialize registration before replacing the device store in widget tests.
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  final _ = InAppPurchase.instance;
  debugDefaultTargetPlatformOverride = null;
  InAppPurchasePlatform.instance = FakePurchasePlatform();
  // Platform package metadata is unavailable inside the widget fake clock.
  PackageInfo.setMockInitialValues(
    appName: 'PasKluis',
    packageName: 'nl.paskluis.app',
    version: '1.5.2',
    buildNumber: '43',
    buildSignature: 'test',
  );
  await testMain();
}
