/// User-entered euro amounts, converted to exact cents without floating point.
int? parseMoneyCents(String input) {
  final text = input.trim();
  if (!RegExp(r'^\d{1,9}([.,]\d{1,2})?$').hasMatch(text)) return null;
  final parts = text.replaceAll(',', '.').split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}
