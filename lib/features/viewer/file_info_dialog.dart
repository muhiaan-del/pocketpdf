import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf_document/pdf_document.dart';

class FileInfoDialog {
  static Future<void> show(
    BuildContext context, {
    required String filePath,
    required String displayName,
    required Uint8List bytes,
  }) async {
    // Read page count from the PDF.
    int pageCount = 0;
    try {
      final doc = PdfDocument.open(bytes);
      pageCount = doc.pageCount;
    } catch (_) {
      pageCount = 0;
    }

    // File size on disk, if the file exists.
    String sizeStr = '—';
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final size = await file.length();
        sizeStr = _formatBytes(size);
      }
    } catch (_) {}

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File info'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('Name', displayName),
            _row('Pages', '$pageCount'),
            _row('Size', sizeStr),
            _row('Location', filePath),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}