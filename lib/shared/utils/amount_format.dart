import '../../data/services/locale_service.dart';

String normalizeAmountValue(String value) {
  final cleaned = value.trim().replaceAll(',', '.');
  final amount = double.tryParse(cleaned);
  if (amount == null) return cleaned;
  if (amount == amount.roundToDouble()) return amount.toStringAsFixed(0);
  return amount.toStringAsFixed(2);
}

String formatAmountValue(Object? value) {
  final normalized = normalizeAmountValue(value?.toString() ?? '');
  return LocaleService.languageCode == 'nl' ? normalized.replaceAll('.', ',') : normalized;
}
