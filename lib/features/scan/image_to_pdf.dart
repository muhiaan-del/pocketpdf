import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ImageToPdf {
  /// Converts a list of image file paths into a single PDF.
  ///
  /// - Applies EXIF rotation so portrait/landscape photos render upright.
  /// - Matches page orientation (A4 portrait or landscape) to the image.
  /// - Uses BoxFit.contain so nothing is cropped or stretched.
  static Future<Uint8List> convertImagesToPdf(List<String> imagePaths) async {
    final doc = pw.Document();

    for (final path in imagePaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;

      // Bake EXIF orientation into pixels, then re-encode (strips EXIF).
      final oriented = img.bakeOrientation(decoded);
      final normalized =
          Uint8List.fromList(img.encodeJpg(oriented, quality: 92));

      final image = pw.MemoryImage(normalized);

      // Match page orientation to the actual image.
      final isLandscape = oriented.width > oriented.height;
      final pageFormat = isLandscape
          ? PdfPageFormat.a4.landscape
          : PdfPageFormat.a4;

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    return doc.save();
  }
}