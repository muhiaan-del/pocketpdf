import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_ocr_ondevice/pdf_ocr_ondevice.dart';

class OcrService {
  /// Whether OCR is available on the current platform.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  /// Adds a searchable text layer to a scanned PDF.
  ///
  /// Runs OCR via the on-device engine, refines the spans (shrinks vertical
  /// bounds, splits lines into words) so search and markup align with the
  /// visible text, then injects the layer.
  static Future<Uint8List> addSearchableTextLayer(
    Uint8List pdfBytes, {
    void Function(double? fraction)? onProgress,
  }) async {
    if (!isSupported) return pdfBytes;
    if (!PdfOcrModelManager.isSupported) return pdfBytes;

    final manager = PdfOcrModelManager();
    final model = PdfOcrModels.ppOcrV5Mobile;
    OnDeviceOcrEngine? engine;

    try {
      // 1. Download the model once (cached afterwards).
      if (!await manager.isDownloaded(model)) {
        await manager.download(
          model,
          onProgress: (p) => onProgress?.call(p.fraction),
        );
      }

      // 2. Build the engine.
      engine = await OnDeviceOcrEngine.fromDownloadedModel(manager, model);

      // 3. Run OCR per page and inject a refined text layer.
      final doc = PdfDocument.open(pdfBytes);
      final editor = PdfEditor(doc);
      const rasterizer = PdfRendererOcrRasterizer();

      for (var pageIndex = 0; pageIndex < doc.pageCount; pageIndex++) {
        final page = doc.page(pageIndex);

        // Rasterize the page for the engine.
        final pageImage = await rasterizer.rasterize(
          page,
          pageIndex: pageIndex,
          pixelRatio: 2,
        );

        try {
          // Run OCR — returns one PdfOcrSpan per recognized line.
          final rawSpans = await engine.recognize(pageImage);

          // Refine: split lines into words, tighten bounds.
          final refined = _refineSpans(rawSpans);

          // Inject using the editor's text-layer API.
          editor.injectTextLayer(pageIndex, refined);
        } finally {
          pageImage.dispose();
        }
      }

      return editor.hasChanges ? editor.save() : pdfBytes;
    } catch (e, stack) {
      debugPrint('On-device OCR failed: $e\n$stack');
      return pdfBytes;
    } finally {
      await engine?.dispose();
      manager.close();
    }
  }

  /// Splits each line-level span into per-word spans and shrinks the
  /// vertical bounds so the injected text layer aligns with the visible
  /// glyphs rather than the padded OCR box.
  static List<PdfOcrSpan> _refineSpans(List<PdfOcrSpan> input) {
    final output = <PdfOcrSpan>[];

    for (final span in input) {
      final text = span.text;
      if (text.trim().isEmpty) continue;

      final b = span.bounds;
      final h = b.height;
      // Shrink top more than bottom: PP-OCR boxes extend further above
      // the caps than below the baseline.
      final newBottom = b.bottom + h * 0.05;
      final newTop = b.top - h * 0.15;
      if (newTop <= newBottom) continue;

      final words = text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (words.isEmpty) continue;

      if (words.length == 1) {
        output.add(PdfOcrSpan(
          text: words.first,
          bounds: PdfRect(b.left, newBottom, b.right, newTop),
          confidence: span.confidence,
        ));
        continue;
      }

      // Multi-word line — distribute the horizontal width proportionally
      // to each word's character count.
      final totalChars = words.fold<int>(0, (sum, w) => sum + w.length);
      final width = b.width;
      var x = b.left;
      for (final word in words) {
        final wordWidth = width * (word.length / totalChars);
        output.add(PdfOcrSpan(
          text: word,
          bounds: PdfRect(x, newBottom, x + wordWidth, newTop),
          confidence: span.confidence,
        ));
        x += wordWidth;
      }
    }

    return output;
  }
}