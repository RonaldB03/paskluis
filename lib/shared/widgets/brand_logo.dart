import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final double? scale;

  const BrandLogo({
    super.key,
    required this.source,
    this.fit = BoxFit.contain,
    this.scale,
  });

  double get effectiveScale {
    if (scale != null) return scale!;
    final normalized = source.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normalized.contains('gallgall')) return 1.75;
    if (normalized.contains('albertheijn')) return 0.95;
    return 1.25;
  }

  @override
  Widget build(BuildContext context) {
    final image = source.startsWith('https://') || source.startsWith('http://')
        ? Image.network(
            source,
            fit: fit,
            errorBuilder: (_, _, _) => const Icon(Icons.credit_card_rounded),
          )
        : Image.asset(
            source,
            fit: fit,
            errorBuilder: (_, _, _) => const Icon(Icons.credit_card_rounded),
          );

    return ClipRect(
      child: Transform.scale(scale: effectiveScale, child: image),
    );
  }
}
