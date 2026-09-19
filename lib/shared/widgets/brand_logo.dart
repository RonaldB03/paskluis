import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Displays every supplied brand image at the largest safe size.
///
/// Empty transparent or single-colour margins are detected automatically.
/// The remaining logo is always fitted inside the available box without
/// stretching or clipping. [fit] and [scale] remain in the API for older
/// call sites, but sizing is intentionally handled here for every brand.
class BrandLogo extends StatefulWidget {
  final String source;
  final BoxFit fit;
  final double? scale;

  const BrandLogo({
    super.key,
    required this.source,
    this.fit = BoxFit.contain,
    this.scale,
  });

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo> {
  static final Map<String, Future<_PreparedLogo>> _cache = {};

  Future<_PreparedLogo> get prepared =>
      _cache.putIfAbsent(widget.source, () => _prepare(widget.source));

  @override
  Widget build(BuildContext context) {
    if (widget.source.isEmpty) {
      return const Icon(Icons.credit_card_rounded);
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: FutureBuilder<_PreparedLogo>(
        future: prepared,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ClipRect(
              child: Transform.scale(
                scale: widget.scale ?? 1.0,
                child: CustomPaint(
                  painter: _LogoPainter(snapshot.data!),
                  size: Size.infinite,
                ),
              ),
            );
          }

          return Image(
            image: _provider(widget.source),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.credit_card_rounded),
          );
        },
      ),
    );
  }

  static ImageProvider _provider(String source) {
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return NetworkImage(source);
    }
    return AssetImage(source);
  }

  static Future<_PreparedLogo> _prepare(String source) async {
    final completer = Completer<ui.Image>();
    final stream = _provider(source).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;

    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(info.image);
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);

    final image = await completer.future;
    final bounds = await _contentBounds(image);
    return _PreparedLogo(image, bounds);
  }

  static Future<Rect> _contentBounds(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      return Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
    }

    final bytes = data.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    List<int> pixel(int x, int y) {
      final index = (y * width + x) * 4;
      return [
        bytes[index],
        bytes[index + 1],
        bytes[index + 2],
        bytes[index + 3],
      ];
    }

    final corners = [
      pixel(0, 0),
      pixel(width - 1, 0),
      pixel(0, height - 1),
      pixel(width - 1, height - 1),
    ];
    final background = List<int>.generate(
      4,
      (channel) =>
          corners.fold<int>(0, (sum, value) => sum + value[channel]) ~/ 4,
    );

    var left = width;
    var top = height;
    var right = -1;
    var bottom = -1;
    final step = width * height > 1600000 ? 2 : 1;

    for (var y = 0; y < height; y += step) {
      for (var x = 0; x < width; x += step) {
        final index = (y * width + x) * 4;
        final alpha = bytes[index + 3];
        if (alpha < 20) continue;

        final difference =
            (bytes[index] - background[0]).abs() +
            (bytes[index + 1] - background[1]).abs() +
            (bytes[index + 2] - background[2]).abs() +
            (alpha - background[3]).abs();
        final visible = background[3] < 20 || difference > 54;
        if (!visible) continue;

        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }

    if (right < left || bottom < top) {
      return Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    }

    final paddingX = ((right - left + 1) * 0.06).round();
    final paddingY = ((bottom - top + 1) * 0.10).round();
    left = (left - paddingX).clamp(0, width - 1).toInt();
    right = (right + paddingX).clamp(0, width - 1).toInt();
    top = (top - paddingY).clamp(0, height - 1).toInt();
    bottom = (bottom + paddingY).clamp(0, height - 1).toInt();

    return Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      (right + 1).toDouble(),
      (bottom + 1).toDouble(),
    );
  }
}

class _PreparedLogo {
  final ui.Image image;
  final Rect sourceRect;

  const _PreparedLogo(this.image, this.sourceRect);
}

class _LogoPainter extends CustomPainter {
  final _PreparedLogo logo;

  const _LogoPainter(this.logo);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final fitted = applyBoxFit(BoxFit.contain, logo.sourceRect.size, size);
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      logo.image,
      logo.sourceRect,
      destination,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.logo.image != logo.image ||
      oldDelegate.logo.sourceRect != logo.sourceRect;
}
