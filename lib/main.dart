import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dart_pdf_editor_assets/dart_pdf_editor_assets.dart';
import 'package:pdf_document/pdf_document.dart';
import 'features/viewer/viewer_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/scan/images_to_pdf_screen.dart';
import 'features/scan/save_service.dart';
import 'features/utils/rename_dialog.dart';
import 'features/utils/recent_files_service.dart';
import 'features/utils/export_image_service.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<RecentFile> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final list = await RecentFilesService.load();
    if (mounted) setState(() => _recent = list);
  }

  Future<void> _openFile(String path, String name) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewerScreen(filePath: path, displayName: name),
      ),
    );
    _loadRecent();
  }

  Future<void> _openPdf() async {
    await ViewerScreen.open(context);
    _loadRecent();
  }

  Future<void> _scan(BuildContext context) async {
    final String? savedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (savedPath == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $savedPath')),
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewerScreen(filePath: savedPath),
      ),
    );
    _loadRecent();
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
    _loadRecent();
  }

  /// Opens a PDF, asks which page, and exports it as a PNG.
  Future<void> _pdfToImage(BuildContext context) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null || file.path == null) return;

    final bytes = await File(file.path!).readAsBytes();

    // Read the actual page count.
    int pageCount = 1;
    try {
      final doc = PdfDocument.open(bytes);
      pageCount = doc.pageCount;
    } catch (_) {
      pageCount = 1;
    }

    if (!context.mounted) return;

    final pageInput = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: '1');
        return AlertDialog(
          title: const Text('Export page as image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This PDF has $pageCount pages.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Page number',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(controller.text.trim());
                Navigator.pop(ctx, n);
              },
              child: const Text('Export'),
            ),
          ],
        );
      },
    );

    if (pageInput == null) return;
    if (pageInput < 1 || pageInput > pageCount) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Page must be between 1 and $pageCount'),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rendering page…')),
    );

    final png = await ExportImageService.renderPageToPng(
      bytes,
      pageInput - 1,
    );

    if (!context.mounted) return;

    if (png == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed')),
      );
      return;
    }

    final baseName = file.path!
        .split(Platform.pathSeparator)
        .last
        .replaceAll('.pdf', '');
    final saved = await SaveService.savePdf(
      png,
      '${baseName}_page$pageInput.png',
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved == null ? 'Save failed' : 'Saved to $saved'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PocketPDF')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              children: [
                const Icon(
                  Icons.picture_as_pdf,
                  size: 56,
                  color: Colors.green,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open, annotate, sign, scan — offline.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3.2,
                  children: [
                    _ActionButton(
                      icon: Icons.folder_open,
                      label: 'Open PDF',
                      primary: true,
                      onTap: () => _openPdf(),
                    ),
                    _ActionButton(
                      icon: Icons.image,
                      label: 'Image to PDF',
                      onTap: () => _imagesToPdf(context),
                    ),
                    _ActionButton(
                      icon: Icons.photo_library_outlined,
                      label: 'PDF to Image',
                      onTap: () => _pdfToImage(context),
                    ),
                    if (Platform.isAndroid)
                      _ActionButton(
                        icon: Icons.document_scanner,
                        label: 'Scan',
                        onTap: () => _scan(context),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _recent.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No recent files.\n'
                        'Open or scan a PDF to see it here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _recent.length,
                    itemBuilder: (context, index) {
                      final f = _recent[index];
                      return ListTile(
                        leading: const Icon(Icons.picture_as_pdf),
                        title: Text(
                          f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _formatDate(f.openedAt),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => _openFile(f.path, f.name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return primary
        ? FilledButton(onPressed: onTap, child: child)
        : FilledButton.tonal(onPressed: onTap, child: child);
  }
}