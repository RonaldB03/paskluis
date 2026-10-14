import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import '../templates/card_templates.dart';

/// Only brand artwork is exported, never a card photo which could contain a PIN.
abstract final class WatchLogos {
  static final _cache = <String, String>{};
  static String source(Map card) {
    final saved = card['logoAsset']?.toString() ?? '';
    if (saved.isNotEmpty) return saved;
    final brand = card['brandId']?.toString();
    for (final template in cardBrandTemplates) {
      if (brand != null && brand == template.id) return template.logoAsset;
    }
    return '';
  }

  static Future<Map<String, String>> build(
    Iterable<Map> cards,
    Set<String> ids, {
    bool garmin = false,
  }) async {
    final selected = cards
        .where((c) => ids.contains(c['id']?.toString()) && source(c).isNotEmpty)
        .toList();
    final result = <String, String>{};
    // Keep every thumbnail within its share of the existing transport budget.
    final overhead = selected.fold<int>(
      2,
      (n, c) => n + utf8.encode(jsonEncode(c['id'].toString())).length + 4,
    );
    final budget = selected.isEmpty
        ? 4500
        : (((79000 - overhead) ~/ selected.length) * 3 ~/ 4).clamp(256, 4500);
    for (var start = 0; start < selected.length; start += 4) {
      final batch = selected.skip(start).take(4);
      final entries = await Future.wait(
        batch.map((card) async {
          final src = source(card);
          final key = '$src|$budget|$garmin';
          String? encoded = _cache[key];
          for (var attempt = 0; encoded == null && attempt < 2; attempt++) {
            try {
              encoded = await _prepare(src, budget, garmin);
            } catch (_) {
              /* retry transient image failures */
            }
          }
          if (encoded == null) return null;
          if (_cache.length >= 128) _cache.remove(_cache.keys.first);
          _cache[key] = encoded;
          return MapEntry(card['id'].toString(), encoded);
        }),
      );
      result.addEntries(entries.whereType<MapEntry<String, String>>());
    }
    return result;
  }

  static Future<String?> _prepare(
    String source,
    int budget,
    bool garmin,
  ) async {
    final ImageProvider provider =
        source.startsWith('http://') || source.startsWith('https://')
        ? NetworkImage(source)
        : AssetImage(source);
    final stream = ResizeImage(
      provider,
      width: 64,
      height: 64,
      policy: ResizeImagePolicy.fit,
    ).resolve(ImageConfiguration.empty);
    final ready = Completer<ui.Image>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!ready.isCompleted) ready.complete(info.image.clone());
      },
      onError: (Object e, StackTrace? stack) {
        if (!ready.isCompleted) ready.completeError(e, stack);
      },
    );
    stream.addListener(listener);
    ui.Image? image;
    try {
      image = await ready.future.timeout(const Duration(seconds: 8));
      for (final side in (garmin ? [24] : [64, 48, 32, 24, 16])) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
        final inner = side * 0.82;
        final fit = applyBoxFit(
          BoxFit.contain,
          ui.Size(image.width.toDouble(), image.height.toDouble()),
          ui.Size(inner, inner),
        );
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          ui.Rect.fromLTWH(
            (side - fit.destination.width) / 2,
            (side - fit.destination.height) / 2,
            fit.destination.width,
            fit.destination.height,
          ),
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        final square = await picture.toImage(side, side);
        picture.dispose();
        final data = await square.toByteData(
          format: garmin ? ui.ImageByteFormat.rawRgba : ui.ImageByteFormat.png,
        );
        square.dispose();
        if (data == null) continue;
        if (garmin) {
          // RGB 2:2:2, one printable character per pixel; 24x24 fits a small packet.
          final out = StringBuffer();
          for (var i = 0; i < data.lengthInBytes; i += 4) {
            final rgb =
                ((data.getUint8(i) >> 6) << 4) |
                ((data.getUint8(i + 1) >> 6) << 2) |
                (data.getUint8(i + 2) >> 6);
            out.writeCharCode(48 + rgb);
          }
          return out.toString();
        }
        if (data.lengthInBytes <= budget) {
          return base64Encode(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        }
      }
      return null;
    } finally {
      stream.removeListener(listener);
      image?.dispose();
    }
  }
}
