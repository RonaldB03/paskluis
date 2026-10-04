import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
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
