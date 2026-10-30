import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Fits both axes; a narrow split window must never squeeze a square QR into
/// a rectangle. The source data and error correction are unchanged.
class AdaptiveQrCode extends StatelessWidget {
  final String data;
  final double maxSize;
  const AdaptiveQrCode({super.key, required this.data, this.maxSize = 300});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = math.min(
        maxSize,
        math.min(constraints.maxWidth, constraints.maxHeight),
      );
      return Center(
        child: QrImageView(
          data: data,
          size: side,
          padding: const EdgeInsets.all(12),
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
        ),
      );
    },
  );
}

/// Uses the actual grid width, including in split-screen and on foldables.
/// Compact phones keep the existing two-column layout.
class AdaptiveCardGridDelegate extends SliverGridDelegate {
  final bool extraClear;
  final double childAspectRatio;
  final double spacing;

  const AdaptiveCardGridDelegate({
    this.extraClear = false,
    required this.childAspectRatio,
    this.spacing = 8,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    final columns = extraClear
        ? math.max(1, (width / 340).floor())
        : width < 280
        ? 1
        : width < 560
        ? 2
        : math.max(3, (width / 200).floor());
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns.clamp(1, 6),
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(AdaptiveCardGridDelegate oldDelegate) =>
      extraClear != oldDelegate.extraClear ||
      childAspectRatio != oldDelegate.childAspectRatio ||
      spacing != oldDelegate.spacing;
}

/// A selected pass stays in one unobstructed pane when the hinge separates
/// the display. Flat displays retain their full width. No cover-display API.
class FoldSafePassView extends StatelessWidget {
  final WidgetBuilder builder;
  const FoldSafePassView({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF4F4F6),
    child: DisplayFeatureSubScreen(
      anchorPoint: Offset.zero,
      child: LayoutBuilder(
        builder: (context, constraints) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: constraints.biggest),
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
}

/// A wide foldable is not a short landscape phone. Only short windows need
/// the existing focused scanner presentation.
bool useCompactPassLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.height < 500;
}

class PassCarouselWidth extends StatelessWidget {
  final Widget child;
  const PassCarouselWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: child,
    ),
  );
}

/// Bounds the pass on large displays and allows vertical scrolling when
/// large text, a keyboard, or a smaller window leaves insufficient height.
class PassCardFrame extends StatelessWidget {
  final Widget child;
  final double minHeight;
  const PassCardFrame({super.key, required this.child, this.minHeight = 560});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = math.max(
        minHeight,
        math.min(constraints.maxHeight, 760.0),
      );
      return SingleChildScrollView(
        child: SizedBox(height: height, child: child),
      );
    },
  );
}
