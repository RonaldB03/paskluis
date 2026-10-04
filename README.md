# PasKluis

PasKluis is een Flutter-app waarmee klantenkaarten, cadeaukaarten, barcodes en
QR-codes lokaal op het apparaat worden bewaard.

## Privacy en opslag

- Kaartgegevens worden lokaal opgeslagen in een AES-versleutelde Hive-box.
- De encryptiesleutel staat in de beveiligde opslag van iOS of Android.
- Eigen kaartfoto’s staan AES-256-GCM-versleuteld in de appmap; ontsleuteling gebeurt in het geheugen. Bestaande foto’s worden bij de upgrade gemigreerd.
- Zonder delen of optionele accountback-up blijven kaartgegevens op het toestel. Bij delen ontvangt de gekozen persoon de kaartgegevens, inclusief een eventuele cadeaukaart-PIN.
- Een ingeschakelde accountback-up bewaart een versleutelde herstelkopie op de PasKluis-server. PasKluis beheert de herstelsleutels: dit is geen end-to-endversleuteling. Alleen geslaagde uploads zijn herstelbaar.
- Gebruikscoördinaten blijven lokaal en worden niet gedeeld of opgenomen in nieuwe back-ups.

## Ontwikkelen

Vereisten:

- Flutter 3.47.6 (dezelfde versie als CI), Dart 3.12 of nieuwer
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
