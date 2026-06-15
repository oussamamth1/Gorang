import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Free, on-device AI verification of identity documents using Google ML Kit
/// text recognition (no API key, no network, no cost).
///
/// The check: OCR the ID card photo and confirm the CIN number the user typed
/// actually appears on the document. If it does, the account is verified
/// automatically; otherwise it falls back to manual review.
class IdVerificationService {
  Future<bool> idCardMatchesCin(XFile image, String cin) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(image.path));
      // Compare digits only — OCR may insert spaces or dots inside numbers.
      for (final block in result.blocks) {
        final digits = block.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.contains(cin)) return true;
      }
      final allDigits = result.text.replaceAll(RegExp(r'[^0-9]'), '');
      return allDigits.contains(cin);
    } catch (_) {
      // OCR unavailable (e.g. unsupported device) — fall back to manual review.
      return false;
    } finally {
      await recognizer.close();
    }
  }
}
