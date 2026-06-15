import 'dart:convert';

import 'package:image_picker/image_picker.dart';

/// Stores images as base64 data URIs inside Firestore documents instead of
/// Firebase Storage (which requires the Blaze plan on new projects).
///
/// Firestore documents are capped at 1 MiB, so images must be picked small
/// (use maxWidth + imageQuality on the picker) and we enforce a hard limit
/// per photo here. A vehicle keeps at most 3 photos for the same reason.
class ImageService {
  /// Raw bytes cap per photo. Base64 adds ~33%, so 200 KB raw ≈ 267 KB
  /// stored — 3 vehicle photos or 2 KYC documents fit comfortably in a doc.
  static const int maxBytes = 200 * 1024;

  Future<String> encodeImage(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw Exception('Photo is too large — please retake it closer up.');
    }
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }
}
