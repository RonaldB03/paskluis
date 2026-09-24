/// Resolves old and current brand identifiers without changing saved links.
String brandDisplayName(String brandId, Map<String, String> names) {
  final id = brandId.trim();
  if (id.isEmpty) return '';
  final exact = names[id]?.trim();
  if (exact != null && exact.isNotEmpty) return exact;

  String normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  final normalized = normalize(id);
  for (final entry in names.entries) {
    if (normalize(entry.key) == normalized && entry.value.trim().isNotEmpty) {
      return entry.value.trim();
    }
  }
  return id.split(RegExp(r'[\s_-]+')).map((word) {
    return word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}';
  }).join(' ');
}
