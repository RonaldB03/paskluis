/// Only explicit expiry labels are accepted; purchase dates are not expiry dates.
DateTime? recogniseExpiryDate(String text) {
  final label = RegExp(
    r'(?:geldig\s*tot|verval(?:datum)?|expiry(?:\s*date)?|expires(?:\s*on)?)\s*[:\-]?\s*(\d{1,2})[\-\/.](\d{1,4})(?:[\-\/.](\d{2}|\d{4}))?(?!\d|[\-\/.]\d)',
    caseSensitive: false,
  ).firstMatch(text);
  if (label == null) return null;
  final first = int.parse(label.group(1)!);
  final second = int.parse(label.group(2)!);
  final third = label.group(3);
  if (third == null) {
    // A short month/year such as 12/27.
    if (first < 1 || first > 12) return null;
    if (label.group(2)!.length != 2 && label.group(2)!.length != 4) return null;
    final year = second < 100 ? 2000 + second : second;
    if (year < 2000 || year > 2199) return null;
    return DateTime(year, first + 1, 0);
  }
  var year = int.parse(third);
  if (year < 100) year += 2000;
  if (year < 2000 || year > 2199 || second > 12) return null;
  final date = DateTime(year, second, first);
  return date.year == year && date.month == second && date.day == first
      ? date
      : null;
}
