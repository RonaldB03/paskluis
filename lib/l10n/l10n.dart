import 'package:flutter/widgets.dart';
import '../data/services/locale_service.dart';
import 'generated/app_localizations.dart';
import 'generated/app_localizations_en.dart';
import 'generated/app_localizations_nl.dart';

/// Typed, offline translations shared by widgets and background services.
abstract final class L10n {
  static final AppLocalizations _dutch = AppLocalizationsNl();
  static final AppLocalizations _english = AppLocalizationsEn();
  static AppLocalizations get current =>
      LocaleService.languageCode == 'nl' ? _dutch : _english;

  static String cardType(String? type) => switch (type) {
    'Cadeaukaart' => current.cardTypeGift,
    'QR-code' => current.qrCode,
    'QR-set' => current.qrSet,
    _ => current.cardTypeLoyalty,
  };

  /// Register a locale dependency, including for widgets with const constructors.
  static void watch(BuildContext context) => Localizations.localeOf(context);
}
