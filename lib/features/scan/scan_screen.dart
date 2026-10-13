import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'image_to_pdf.dart';
import 'save_service.dart';
import '../ocr/ocr_service.dart';
import '../utils/rename_dialog.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _busy = false;
  bool _runOcr = false;

  Future<void> _startScan() async {
    setState(() => _busy = true);
    final allImages = <String>[];

    try {
      debugPrint('=== SCAN START ===');

      final first = await CunningDocumentScanner.getPictures(
        noOfPages: 10,
        isGalleryImportAllowed: true,
        androidScannerMode: AndroidScannerMode.full,
      );

      if (first == null || first.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                first == null
                    ? 'Scanner was cancelled or failed to open.'
                    : 'No pages were captured.',
              ),
            ),
          );
          setState(() => _busy = false);
        }
        return;
      }
      allImages.addAll(first);

      while (mounted) {
        final addMore = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(
              '${allImages.length} page${allImages.length == 1 ? '' : 's'} captured',
            ),
            content: const Text('Add another page to this PDF?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Finish'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                onPressed: () => Navigator.pop(ctx, true),
                label: const Text('Add page'),
              ),
            ],
          ),
        );

        if (addMore != true) break;

        final more = await CunningDocumentScanner.getPictures(
          noOfPages: 10,
          isGalleryImportAllowed: true,
          androidScannerMode: AndroidScannerMode.full,
        );

        if (more == null || more.isEmpty) break;
        allImages.addAll(more);
      }

      if (allImages.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      Uint8List pdfBytes = await ImageToPdf.convertImagesToPdf(allImages);

      if (_runOcr && OcrService.isSupported) {
        pdfBytes = await OcrService.addSearchableTextLayer(pdfBytes);
      }

      if (!mounted) return;
      final defaultName =
          'scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final fileName = await RenameDialog.show(context, defaultName);
      if (fileName == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final savedPath = await SaveService.savePdf(pdfBytes, fileName);

      if (!mounted) return;
      if (savedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save scan — check storage permissions.'),
          ),
        );
        setState(() => _busy = false);
        return;
      }

      Navigator.of(context).pop<String>(savedPath);
    } catch (e, stack) {
      debugPrint('=== SCAN EXCEPTION ===\n$e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
      setState(() => _busy = false);
    }
  }

  Future<void> _showOcrInfo() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('What OCR does'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'When ON, the scanned pages become real text. You can then:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              _BulletLine('🔍', 'Search', 'Find any word in the scan'),
              _BulletLine('👆', 'Select', 'Long-press a word to select it'),
              _BulletLine('📋', 'Copy', 'Copy text into other apps'),
              _BulletLine('🖍', 'Highlight & Underline',
                  'Mark up real text, not just freehand'),
              _BulletLine('📤', 'Extract text', 'Save the text as a .txt file'),
              SizedBox(height: 16),
              Text(
                'Trade-off: OCR is slower — a scan can take 30–90 seconds '
                'on budget devices. Without OCR, scanning is near-instant.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Document')),
      body: Center(
        child: _busy
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text(
                      'Scanning and processing…\n'
                      'This can take up to a minute if OCR is on.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.document_scanner, size: 96),
                    const SizedBox(height: 24),
                    const Text(
                      'Scan paper into PDF',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tip: tap + inside the scanner to capture multiple pages.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Start Scanning'),
                      onPressed: _startScan,
                    ),
                    if (OcrService.isSupported) ...[
                      const SizedBox(height: 24),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Make text searchable (OCR)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Adds search, selection & markup '
                                      '— slower to save',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline, size: 20),
                                tooltip: 'What does OCR do?',
                                onPressed: _showOcrInfo,
                              ),
                              Switch(
                                value: _runOcr,
                                onChanged: (v) => setState(() => _runOcr = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String icon;
  final String label;
  final String description;

  const _BulletLine(this.icon, this.label, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: '$label — ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}