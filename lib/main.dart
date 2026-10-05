import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dart_pdf_editor_assets/dart_pdf_editor_assets.dart';
import 'features/viewer/viewer_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/scan/images_to_pdf_screen.dart';
import 'features/scan/save_service.dart';
import 'features/utils/rename_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledEditorAssets();
  runApp(const PocketPdfApp());
}

class PocketPdfApp extends StatelessWidget {
  const PocketPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketPDF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _scan(BuildContext context) async {
    final Uint8List? result = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (result == null || !context.mounted) return;

    final defaultName = 'scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final fileName = await RenameDialog.show(context, defaultName);
    if (fileName == null || !context.mounted) return;

    final savedPath = await SaveService.savePdf(result, fileName);
    if (!context.mounted) return;

    if (savedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save scan')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $savedPath')),
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewerScreen(filePath: savedPath),
      ),
    );
  }

  Future<void> _imagesToPdf(BuildContext context) async {
    final Uint8List? result = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const ImagesToPdfScreen()),
    );
    if (result == null || !context.mounted) return;

    final defaultName =
        'images_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final fileName = await RenameDialog.show(context, defaultName);
    if (fileName == null || !context.mounted) return;

    final savedPath = await SaveService.savePdf(result, fileName);
    if (!context.mounted) return;

    if (savedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save PDF')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $savedPath')),
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewerScreen(filePath: savedPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PocketPDF')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 96, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              'Open, annotate, sign, scan — offline.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Open PDF'),
              onPressed: () => ViewerScreen.open(context),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.image),
              label: const Text('Images to PDF'),
              onPressed: () => _imagesToPdf(context),
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.document_scanner),
                label: const Text('Scan Document'),
                onPressed: () => _scan(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}