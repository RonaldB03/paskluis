String watchSelectionError(FormatException error, String language) {
  final nl = language == 'nl';
  final name = error.source is String && (error.source as String).isNotEmpty
      ? error.source as String
      : (nl ? 'Deze pas' : 'This card');
  return switch (error.message) {
    'too_wide' =>
      nl
          ? '$name: de code is te breed of te groot om op het horloge weer te geven. Gebruik deze pas op je telefoon.'
          : '$name: the code is too wide or large to display on the watch. Use this card on your phone.',
    'unsupported' =>
      nl
          ? '$name: dit barcodeformaat wordt nog niet ondersteund op het horloge. Gebruik deze pas op je telefoon.'
          : '$name: this barcode format is not yet supported on the watch. Use this card on your phone.',
    'invalid_code' =>
      nl
          ? '$name: de code past niet bij het opgeslagen barcodeformaat. Scan de originele pas opnieuw om het formaat te controleren.'
          : '$name: the code does not match its saved barcode format. Scan the original card again to check the format.',
    'code_too_long' =>
      nl
          ? '$name: deze code bevat meer tekens dan de horloge-app ondersteunt. Gebruik deze pas op je telefoon.'
          : '$name: this code contains more characters than the watch app supports. Use this card on your phone.',
    'too_large' =>
      nl
          ? 'Deze selectie bevat te veel gegevens voor één synchronisatie. Selecteer minder pasjes.'
          : 'This selection contains too much data for one sync. Select fewer cards.',
    _ =>
      nl
          ? '$name kan niet naar het horloge worden verstuurd. Gebruik deze pas op je telefoon.'
          : '$name cannot be sent to the watch. Use this card on your phone.',
  };
}
