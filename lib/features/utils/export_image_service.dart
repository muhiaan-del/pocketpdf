import 'dart:typed_data';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';
import 'package:image/image.dart' as img;

class ExportImageService {
  /// Renders a single page of a PDF to PNG bytes.
  ///
  /// [pageIndex] is zero-based.
  /// [pixelRatio] scales the output (2.0 = 2x resolution).
  ///
  /// Returns null if rendering failed.
  static Future<Uint8List?> renderPageToPng(
    Uint8List pdfBytes,
    int pageIndex, {
    double pixelRatio = 2.0,
  }) async {
    try {
      final doc = PdfDocument.open(pdfBytes);
      if (pageIndex < 0 || pageIndex >= doc.pages.length) return null;

      final page = doc.pages[pageIndex];
      final pageWidth = (page.width * pixelRatio).round();
      final pageHeight = (page.height * pixelRatio).round();

      final pdfImage = await page.render(
        width: pageWidth,
        height: pageHeight,
      );
      await pdfImage.createImage();

      final w = pdfImage.width;
      final h = pdfImage.height;
      final pixels = pdfImage.pixels;

      final out = img.Image(width: w, height: h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          final r = pixels[i];
          final g = pixels[i + 1];
          final b = pixels[i + 2];
          out.setPixelRgb(x, y, r, g, b);
        }
      }

      return Uint8List.fromList(img.encodePng(out));
    } catch (_) {
      return null;
    }
  }
}