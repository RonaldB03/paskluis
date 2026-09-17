import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final String source;
  final BoxFit fit;

  const BrandLogo({
    super.key,
    required this.source,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return Image.network(
        source,
        fit: fit,
        errorBuilder: (_, _, _) => const Icon(Icons.credit_card_rounded),
      );
    }
    return Image.asset(
      source,
      fit: fit,
      errorBuilder: (_, _, _) => const Icon(Icons.credit_card_rounded),
    );
  }
}
