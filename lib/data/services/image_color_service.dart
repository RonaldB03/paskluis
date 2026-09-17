import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Determines the colour surrounding a user supplied logo.
///
/// Logos are commonly supplied as a square image with the brand colour around
/// the mark. Sampling the outer edge (instead of the centre/logo itself) makes
/// the result stable for examples such as a white ERS mark on black.
class ImageColorService {
  const ImageColorService._();

  static Future<Color?> dominantEdgeColor(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 96,
        targetHeight: 96,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        image.dispose();
        codec.dispose();
        return null;
      }

      final buckets = <int, _ColorBucket>{};
      final edgeDepth =
          ((image.width < image.height ? image.width : image.height) * .14)
              .round()
              .clamp(1, 14);

      void addPixel(int x, int y) {
        final offset = (y * image.width + x) * 4;
        final r = byteData.getUint8(offset);
        final g = byteData.getUint8(offset + 1);
        final b = byteData.getUint8(offset + 2);
        final a = byteData.getUint8(offset + 3);
        if (a < 40) return;
        // Quantise small compression/anti-aliasing differences together.
        final key = ((r ~/ 16) << 8) | ((g ~/ 16) << 4) | (b ~/ 16);
        final bucket = buckets.putIfAbsent(key, _ColorBucket.new);
        bucket.count += 1;
        bucket.red += r;
        bucket.green += g;
        bucket.blue += b;
      }

      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final isEdge = x < edgeDepth ||
              y < edgeDepth ||
              x >= image.width - edgeDepth ||
              y >= image.height - edgeDepth;
          if (isEdge) addPixel(x, y);
        }
      }

      image.dispose();
      codec.dispose();

      if (buckets.isEmpty) return null;
      final winner = buckets.values.reduce(
        (a, b) => a.count >= b.count ? a : b,
      );

      return Color.fromARGB(
        255,
        winner.red ~/ winner.count,
        winner.green ~/ winner.count,
        winner.blue ~/ winner.count,
      );
    } catch (_) {
      return null;
    }
  }
}

class _ColorBucket {
  int count = 0;
  int red = 0;
  int green = 0;
  int blue = 0;
}
