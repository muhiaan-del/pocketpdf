import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'image_to_pdf.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _busy = false;
  final List<String> _allImages = [];

  Future<void> _runScanner() async {
    try {
      final images = await CunningDocumentScanner.getPictures(
        noOfPages: 10,
        isGalleryImportAllowed: true,
      );
      if (images != null && images.isNotEmpty) {
        _allImages.addAll(images);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  Future<void> _startScan() async {
    setState(() => _busy = true);
    _allImages.clear();

    await _runScanner();

    // Loop: keep asking if the user wants more pages
    while (mounted) {
      if (_allImages.isEmpty) break;

      final addMore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text('Page ${_allImages.length} captured'),
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
      await _runScanner();
    }

    if (_allImages.isEmpty) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    // Convert all collected pages into one PDF
    final pdfBytes = await ImageToPdf.convertImagesToPdf(_allImages);

    if (!mounted) return;
    Navigator.of(context).pop<Uint8List>(pdfBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Document')),
      body: Center(
        child: _busy
            ? const CircularProgressIndicator()
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
                  ],
                ),
              ),
      ),
    );
  }
}