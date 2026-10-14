import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Optional thumbnails travel separately from the bounded barcode protocol.
abstract final class WatchLogos {
  static Future<Map<String, String>> build(
    Iterable<Map> cards,
    Set<String> ids,
  ) async {
    final results = await Future.wait(
      cards.where((c) => ids.contains(c['id']?.toString())).take(12).map((
        card,
      ) async {
        final source = card['logoAsset']?.toString() ?? '';
        if (source.isEmpty) return null;
        try {
          final provider =
              source.startsWith('https://') || source.startsWith('http://')
              ? NetworkImage(source) as ImageProvider
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
            onError: (Object error, StackTrace? stack) {
              if (!ready.isCompleted) ready.completeError(error, stack);
            },
          );
          stream.addListener(listener);
          ui.Image? image;
          try {
            image = await ready.future.timeout(const Duration(seconds: 4));
            final recorder = ui.PictureRecorder();
            final canvas = ui.Canvas(recorder);
            canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
            final fit = applyBoxFit(
              BoxFit.contain,
              ui.Size(image.width.toDouble(), image.height.toDouble()),
              const ui.Size(56, 56),
            );
            final destination = ui.Rect.fromLTWH(
              (64 - fit.destination.width) / 2,
              (64 - fit.destination.height) / 2,
              fit.destination.width,
              fit.destination.height,
            );
            canvas.drawImageRect(
              image,
              ui.Rect.fromLTWH(
                0,
                0,
                image.width.toDouble(),
                image.height.toDouble(),
              ),
              destination,
              ui.Paint()..filterQuality = ui.FilterQuality.medium,
            );
            final picture = recorder.endRecording();
            final square = await picture.toImage(64, 64);
            picture.dispose();
            final data = await square.toByteData(
              format: ui.ImageByteFormat.png,
            );
            square.dispose();
            if (data == null || data.lengthInBytes > 4500) return null;
            return MapEntry(
              card['id'].toString(),
              base64Encode(
                data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              ),
            );
          } finally {
            stream.removeListener(listener);
            image?.dispose();
          }
        } catch (_) {
          // A missing/offline logo must never prevent card transfer or deletion.
          return null;
        }
      }),
    );
    return Map.fromEntries(results.whereType<MapEntry<String, String>>());
  }
}
