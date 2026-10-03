import 'package:flutter/material.dart';
import 'package:dart_pdf_editor_assets/dart_pdf_editor_assets.dart';
import 'features/viewer/viewer_screen.dart';

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
          ],
        ),
      ),
    );
  }
}