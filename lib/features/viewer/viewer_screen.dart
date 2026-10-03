import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';

class ViewerScreen extends StatefulWidget {
  final String filePath;
  const ViewerScreen({super.key, required this.filePath});

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
    _bytesFuture = File(widget.filePath).readAsBytes();
  }

  Future<void> _save(Uint8List bytes) async {
    final dir = File(widget.filePath).parent;
    final baseName = widget.filePath
        .split(Platform.pathSeparator)
        .last
        .replaceAll('.pdf', '');
    final output = File('${dir.path}/${baseName}_edited.pdf');
    await output.writeAsBytes(bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to ${output.path}')),
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
            title: Text(widget.filePath.split(Platform.pathSeparator).last),
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