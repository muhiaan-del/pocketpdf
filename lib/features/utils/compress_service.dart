import 'dart:typed_data';
import 'package:pdf_document/pdf_document.dart';

class CompressService {
  /// Compresses a PDF using pdf_document's built-in PdfCompressor.
  /// Returns the compressed bytes, or null if compression failed.
  ///
  /// Note: This performs stream-level compaction (drops unreachable objects,
  /// rewrites xref). It does NOT re-encode embedded images, so scanned PDFs
  /// with large photos will shrink only modestly (typically 5–20%).
  static Future<Uint8List?> compress(Uint8List input) async {
    try {
      final doc = PdfDocument.open(input);
      final result = PdfCompressor.optimize(doc);
      return result.bytes;
    } catch (_) {
      return null;
    }
  }
}