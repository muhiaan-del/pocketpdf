import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:pdf_document/pdf_document.dart';

class ExportImageService {
  /// Renders a single page of a PDF to PNG bytes.
  ///
  /// [pageIndex] is zero-based. [pixelRatio] scales the output
  /// (2.0 = 2x resolution). Returns null if rendering failed.
  static Future<Uint8List?> renderPageToPng(
    Uint8List pdfBytes,
    int pageIndex, {
    double pixelRatio = 2.0,
  }) async {
    try {
      final doc = PdfDocument.open(pdfBytes);
      if (pageIndex < 0 || pageIndex >= doc.pageCount) return null;

      final page = doc.page(pageIndex);

      // PdfPageRenderer is from dart_pdf_editor; it returns a ui.Image.
      final image = await PdfPageRenderer.renderImage(
        page,
        pixelRatio: pixelRatio,
      );
      try {
        final data = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) return null;
        return Uint8List.fromList(
          data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
        );
      } finally {
        image.dispose();
      }
    } catch (_) {
      return null;
    }
  }
}