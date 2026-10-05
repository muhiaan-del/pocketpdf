import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../scan/save_service.dart';
import '../utils/rename_dialog.dart';
import '../utils/compress_service.dart';

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
  late final Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    if (widget.bytes != null) {
      _bytesFuture = Future.value(widget.bytes);
    } else {
      _bytesFuture = File(widget.filePath!).readAsBytes();
    }
  }

  String get _currentName =>
      widget.displayName ??
      widget.filePath?.split(Platform.pathSeparator).last ??
      'document.pdf';

  Future<void> _save(Uint8List bytes) async {
    final baseName = _currentName.replaceAll('.pdf', '');
    final fileName = '${baseName}_edited.pdf';
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
    }
  }

  Future<void> _rename(Uint8List bytes) async {
    final newName = await RenameDialog.show(context, _currentName);
    if (newName == null || !mounted) return;

    final saved = await SaveService.savePdf(bytes, newName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null ? 'Rename failed' : 'Saved as $newName',
        ),
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

    final baseName = _currentName.replaceAll('.pdf', '');
    final saved = await SaveService.savePdf(
      result,
      '${baseName}_compressed.pdf',
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
                ],
              ),
            ],
          ),
          body: PdfEditorView(
            bytes: snapshot.data!,
            onSave: _save,
            features: const PdfEditorFeatures(
              tools: {
                PdfEditTool.select,
                PdfEditTool.highlight,
                PdfEditTool.ink,
                PdfEditTool.freeText,
                PdfEditTool.signature,
              },
            ),
          ),
        );
      },
    );
  }
}