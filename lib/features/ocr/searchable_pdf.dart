import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf_document/pdf_document.dart';
import 'ocr_service.dart';

class SearchablePdf {
  /// Injects an invisible OCR text layer over each page of a scanned PDF.
  ///
  /// [pdfBytes] is the scan PDF (image-only pages).
  /// [imagePaths] is the list of image files, one per page, in page order.
  /// [spansByPage] maps page index (0-based) to the OCR spans for that page
  /// (pixel-space bounds from ML Kit).
  ///
  /// Returns a new PDF with the text layer. If nothing can be injected,
  /// returns the original [pdfBytes] unchanged.
  static Future<Uint8List> addTextLayer({
    required Uint8List pdfBytes,
    required List<String> imagePaths,
    required Map<int, List<OcrSpan>> spansByPage,
  }) async {
    final doc = PdfDocument.open(pdfBytes);
    final editor = PdfEditor(doc);

    for (var pageIndex = 0;
        pageIndex < doc.pageCount && pageIndex < imagePaths.length;
        pageIndex++) {
      final spans = spansByPage[pageIndex];
      if (spans == null || spans.isEmpty) continue;

      // Decode the source image to get its native pixel dimensions.
      final imageBytes = await _readFile(imagePaths[pageIndex]);
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) continue;

      final page = doc.page(pageIndex);
      final pageWidth = page.cropBox.width;
      final pageHeight = page.cropBox.height;

      // Compute the image-fit transform (BoxFit.contain inside the page).
      final imageW = decoded.width.toDouble();
      final imageH = decoded.height.toDouble();
      final scale = _min(pageWidth / imageW, pageHeight / imageH);
      final fittedW = imageW * scale;
      final fittedH = imageH * scale;
      final offsetX = (pageWidth - fittedW) / 2;
      final offsetY = (pageHeight - fittedH) / 2;

      final pdfSpans = <PdfOcrSpan>[];
      for (final span in spans) {
        final b = span.bounds;

        // Pixel space (top-left origin) -> PDF user space (bottom-left origin).
        final pdfLeft = offsetX + b.left * scale;
        final pdfRight = offsetX + b.right * scale;
        final pdfTop = pageHeight - (offsetY + b.top * scale);
        final pdfBottom = pageHeight - (offsetY + b.bottom * scale);

        pdfSpans.add(PdfOcrSpan(
          text: span.text,
          bounds: PdfRect(pdfLeft, pdfBottom, pdfRight, pdfTop),
          confidence: span.confidence,
        ));
      }

      editor.injectTextLayer(pageIndex, pdfSpans);
    }

    return editor.hasChanges ? editor.save() : pdfBytes;
  }

  static double _min(double a, double b) => a < b ? a : b;

  static Future<Uint8List> _readFile(String path) async {
    return Uint8List.fromList(await File(path).readAsBytes());
  }
}