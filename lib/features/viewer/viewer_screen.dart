import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../scan/save_service.dart';
import '../utils/rename_dialog.dart';
import '../utils/compress_service.dart';
import '../utils/recent_files_service.dart';
import '../utils/export_image_service.dart';
import 'file_info_dialog.dart';

class ViewerScreen extends StatefulWidget {
  final String? filePath;
  final Uint8List? bytes;
  final String? displayName;

  const ViewerScreen({
    super.key,
    this.filePath,
    this.bytes,
    this.displayName,
  }) : assert(filePath != null || bytes != null,
            'Provide either filePath or bytes');

  static Future<void> open(BuildContext context) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null || file.path == null) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewerScreen(filePath: file.path!),
      ),
    );
  }

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  static const _tipShownKey = 'pocketpdf_tip_banner_v1';

  late final Future<Uint8List> _bytesFuture;
  bool _showTipBanner = true;

  @override
  void initState() {
    super.initState();
    if (widget.bytes != null) {
      _bytesFuture = Future.value(widget.bytes);
    } else {
      _bytesFuture = File(widget.filePath!).readAsBytes();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool(_tipShownKey) == true) {
          if (mounted) setState(() => _showTipBanner = false);
        }
      } catch (_) {}
      _recordRecent();
    });
  }

  Future<void> _dismissTip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_tipShownKey, true);
    } catch (_) {}
    if (mounted) setState(() => _showTipBanner = false);
  }

  Future<void> _recordRecent() async {
    final path = widget.filePath;
    if (path == null) return;
    await RecentFilesService.record(path, _currentName);
  }

  String get _currentName =>
      widget.displayName ??
      widget.filePath?.split(Platform.pathSeparator).last ??
      'document.pdf';

  String get _baseName => _currentName.replaceAll('.pdf', '');

  Future<void> _save(Uint8List bytes) async {
    final fileName = '${_baseName}_edited.pdf';
    final outPath = await SaveService.savePdf(bytes, fileName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(outPath == null ? 'Save failed' : 'Saved to $outPath'),
      ),
    );
  }

  Future<void> _share(Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final tempFile = File('${dir.path}/$_currentName');
      await tempFile.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: _currentName,
        text: 'Shared from PocketPDF',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _onMenuAction(String action, Uint8List bytes) async {
    switch (action) {
      case 'rename':
        await _rename(bytes);
        break;
      case 'compress':
        await _compress(bytes);
        break;
      case 'info':
        await _showFileInfo(bytes);
        break;
      case 'export_image':
        await _exportPageAsImage(bytes);
        break;
    }
  }

  Future<void> _rename(Uint8List bytes) async {
    final newName = await RenameDialog.show(context, _currentName);
    if (newName == null || !mounted) return;

    final saved = await SaveService.savePdf(bytes, newName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved == null ? 'Rename failed' : 'Saved as $newName'),
      ),
    );
  }

  Future<void> _compress(Uint8List bytes) async {
    final originalSize = bytes.length;
    final result = await CompressService.compress(bytes);

    if (!mounted) return;

    if (result == null || result.length >= originalSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already optimized — no reduction possible'),
        ),
      );
      return;
    }

    final saved = await SaveService.savePdf(
      result,
      '${_baseName}_compressed.pdf',
    );

    if (!mounted) return;

    final savedPct =
        (100 - (result.length / originalSize * 100)).toStringAsFixed(0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Compressed by $savedPct% → ${saved ?? 'save failed'}',
        ),
      ),
    );
  }

  Future<void> _showFileInfo(Uint8List bytes) async {
    final path = widget.filePath;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File info only available for saved files'),
        ),
      );
      return;
    }
    await FileInfoDialog.show(
      context,
      filePath: path,
      displayName: _currentName,
      bytes: bytes,
    );
  }

  Future<void> _exportPageAsImage(Uint8List bytes) async {
    final doc = PdfDocument.open(bytes);

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
              Text('This PDF has ${doc.pageCount} pages.'),
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
    if (pageInput < 1 || pageInput > doc.pageCount) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Page must be between 1 and ${doc.pageCount}'),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rendering page…')),
    );

    final png = await ExportImageService.renderPageToPng(
      bytes,
      pageInput - 1,
    );

    if (!mounted) return;

    if (png == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed')),
      );
      return;
    }

    final saved = await SaveService.savePdf(
      png,
      '${_baseName}_page$pageInput.png',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null ? 'Save failed' : 'Saved to $saved',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Failed to load: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_currentName),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onPressed: () => _share(snapshot.data!),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _onMenuAction(value, snapshot.data!),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Rename'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'compress',
                    child: ListTile(
                      leading: Icon(Icons.compress),
                      title: Text('Compress'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'info',
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('File info'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export_image',
                    child: ListTile(
                      leading: Icon(Icons.image_outlined),
                      title: Text('Export page as image'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (_showTipBanner)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 18,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          Platform.isAndroid
                              ? 'Long-press to select text, then tap Highlight/Underline in the menu.'
                              : 'Drag to select text, then right-click for Highlight/Underline.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Dismiss',
                        onPressed: _dismissTip,
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: PdfEditorView(
                  bytes: snapshot.data!,
                  onSave: _save,
                  features: const PdfEditorFeatures(
                    tools: {
                      PdfEditTool.select,
                      PdfEditTool.ink,
                      PdfEditTool.freeText,
                      PdfEditTool.signature,
                    },
                  ),
                  toolbarBuilder: (context, editing, viewer) {
                    return _AnnotationToolbar(
                      editing: editing,
                      onSave: _save,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnnotationToolbar extends StatelessWidget {
  final PdfEditingController editing;
  final Future<void> Function(Uint8List) onSave;

  const _AnnotationToolbar({
    required this.editing,
    required this.onSave,
  });

  Color? _activeColor(BuildContext context, bool active) =>
      active ? Theme.of(context).colorScheme.primary : null;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: editing,
      builder: (context, _) {
        return BottomAppBar(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.touch_app),
                color: _activeColor(
                  context,
                  editing.tool == PdfEditTool.select,
                ),
                onPressed: () => editing.tool = PdfEditTool.select,
                tooltip: 'Select',
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                color: _activeColor(
                  context,
                  editing.tool == PdfEditTool.ink,
                ),
                onPressed: () => editing.tool = PdfEditTool.ink,
                tooltip: 'Pen',
              ),
              IconButton(
                icon: const Icon(Icons.text_fields),
                color: _activeColor(
                  context,
                  editing.tool == PdfEditTool.freeText,
                ),
                onPressed: () => editing.tool = PdfEditTool.freeText,
                tooltip: 'Text',
              ),
              IconButton(
                icon: const Icon(Icons.draw),
                color: _activeColor(
                  context,
                  editing.tool == PdfEditTool.signature,
                ),
                onPressed: () => editing.tool = PdfEditTool.signature,
                tooltip: 'Signature',
              ),
              const Spacer(),
              IconButton(
                icon: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: editing.displayColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                tooltip: 'Color',
                onPressed: () async {
                  final picked = await showPdfColorPicker(
                    context,
                    initial: editing.displayColor,
                    recentColors: editing.preferences.recentColors,
                    documentColors: editing.documentAnnotationColors(),
                  );
                  if (picked != null) {
                    editing.color = picked;
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () => onSave(editing.bytes),
                tooltip: 'Save',
              ),
            ],
          ),
        );
      },
    );
  }
}