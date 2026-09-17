# PasKluis

PasKluis is een Flutter-app waarmee klantenkaarten, cadeaukaarten, barcodes en
QR-codes lokaal op het apparaat worden bewaard.

## Privacy en opslag

- Kaartgegevens worden lokaal opgeslagen in een AES-versleutelde Hive-box.
- De encryptiesleutel staat in de beveiligde opslag van iOS of Android.
- PasKluis verstuurt kaartgegevens niet naar een account of externe server.
- Zelfgekozen kaartafbeeldingen worden naar de permanente appmap gekopieerd.

## Ontwikkelen

Vereisten:

- Flutter stable met Dart 3.11 of nieuwer
- Xcode voor iOS-builds
- Android Studio/SDK voor Android-builds

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

## Release

De productiebundle-ID is `nl.paskluis.app`. Releasebuilds mogen nooit met een
debugcertificaat worden ondertekend. De iOS-release wordt via Codemagic gebouwd
en gepubliceerd met de geconfigureerde App Store Connect-integratie.

Voor iedere release:

1. Verhoog `version` in `pubspec.yaml`.
2. Draai `flutter analyze` en `flutter test`.
3. Test scannen, afbeeldingsimport, biometrie en opslag op echte apparaten.
4. Controleer signing en storemetadata.
