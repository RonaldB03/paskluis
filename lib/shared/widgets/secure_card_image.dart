import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../data/services/media_storage_service.dart';

/// Decrypts only into memory. No plaintext display cache is written to disk.
class SecureCardImage extends StatefulWidget {
  final File file;
  final BoxFit? fit;
  final double? width, height;
  const SecureCardImage(
    this.file, {
    super.key,
    this.fit,
    this.width,
    this.height,
  });
  @override
  State<SecureCardImage> createState() => _SecureCardImageState();
}

class _SecureCardImageState extends State<SecureCardImage> {
  late Future<Uint8List> _bytes;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bytes = MediaStorageService.readBytes(widget.file.path);
  }

  @override
  void didUpdateWidget(SecureCardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) => snapshot.hasData
        ? Image.memory(
            snapshot.data!,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          )
        : SizedBox(
            width: widget.width,
            height: widget.height,
            child: snapshot.hasError
                ? const Icon(Icons.broken_image_outlined)
                : null,
          ),
  );
}
