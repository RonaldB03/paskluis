/// Conservative fallback when no barcode could be decoded from a photo.
/// Never join separate printed numbers, or choose the longest of competing
/// candidates. The user can scan again or enter the number when ambiguous.
String printedCardNumber(Iterable<String> lines) {
  final candidates = <String>{};
  for (final line in lines) {
    for (final column in line.split(RegExp(r'\t| {2,}'))) {
      for (final match in RegExp(r'\d+(?:[ -]\d+)*').allMatches(column)) {
        final groups = RegExp(
          r'\d+',
        ).allMatches(match.group(0)!).map((part) => part.group(0)!).toList();
        // A complete number beside another number (or PIN) is not a group
        // of digits belonging to the same card number.
        if (groups.any((group) => group.length >= 8)) {
          for (final group in groups) {
            if (group.length >= 8 && group.length <= 24) {
              candidates.add(group);
            }
          }
        } else {
          final number = groups.join();
          if (number.length >= 8 && number.length <= 24) {
            candidates.add(number);
          }
        }
      }
    }
  }
  return candidates.length == 1 ? candidates.single : '';
}
