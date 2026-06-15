import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Renders both base64 data URIs (how photos are stored in Firestore) and
/// regular network URLs. Decoded bytes are cached so list scrolling does not
/// re-decode the same base64 string every frame.
class AppImage extends StatelessWidget {
  const AppImage(this.src, {super.key, this.fit = BoxFit.cover});

  final String src;
  final BoxFit fit;

  static final Map<String, Uint8List> _cache = {};

  @override
  Widget build(BuildContext context) {
    if (src.startsWith('data:')) {
      final bytes = _cache.putIfAbsent(src, () {
        if (_cache.length > 100) _cache.clear();
        return base64Decode(src.substring(src.indexOf(',') + 1));
      });
      return Image.memory(bytes, fit: fit, gaplessPlayback: true);
    }
    return Image.network(src, fit: fit);
  }
}
