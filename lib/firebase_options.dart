// Generated from the Firebase project configuration for PasKluis.
// The values below are public app identifiers, not server credentials.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is niet geconfigureerd voor web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase is niet geconfigureerd voor dit platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDIBlMHVfYoNhHoR2WsTWmSfcAsEGH8Y5o',
    appId: '1:485203469686:android:20bf873beb673862810657',
    messagingSenderId: '485203469686',
    projectId: 'paskluis-db53c',
    storageBucket: 'paskluis-db53c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBWLoSnu2574ei3hgKErtgb8ZneTkbNr3I',
    appId: '1:485203469686:ios:07a41af5d687541c810657',
    messagingSenderId: '485203469686',
    projectId: 'paskluis-db53c',
    storageBucket: 'paskluis-db53c.firebasestorage.app',
    iosBundleId: 'nl.paskluis.app',
  );
}
