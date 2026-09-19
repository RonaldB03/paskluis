double logoLayoutValue(
  Map<String, dynamic> item,
  String context,
  String property,
  double fallback,
) {
  final key =
      'logo${context[0].toUpperCase()}${context.substring(1)}${property[0].toUpperCase()}${property.substring(1)}';
  return double.tryParse(item[key]?.toString() ?? '') ?? fallback;
}
