import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  // Bumped to v2 so the tip reappears once after this update. Change the
  // version suffix any time you want the tip shown again in development.
  static const _tipShownKey = 'pocketpdf_markup_tip_shown_v2';

  late final Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    if (widget.bytes != null) {
      _bytesFuture = Future.value(widget.bytes);
    } else {
      _bytesFuture = File(widget.filePath!).readAsBytes();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTip());
  }

  Future<void> _maybeShowTip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_tipShownKey) == true) return;
      await prefs.setBool(_tipShownKey, true);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('How to mark up text'),
          content: const Text(
            '1. Pick your color with the circle button in the toolbar.\n\n'
            '2. Long-press a word in the PDF to select it. Drag the blue '
            'handles to extend the selection.\n\n'
            '3. Tap Highlight, Underline, Strike out, or Squiggly from the '
            'popup menu.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Tip is non-critical; ignore storage errors.
    }
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
              // DO NOT set `toolGroups` here. Omitting it keeps every group
              // enabled — including markup — which is what wires up the
              // built-in text-selection context menu
              // (Highlight / Underline / Strike out / Squiggly).
              //
              // The custom toolbar below replaces the visible chrome, so the
              // stock markup strip is not drawn anyway. We only restrict
              // which tools the viewer can arm, via `tools`.
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
        );
      },
    );
  }
}

/// Custom annotation toolbar.
///
/// Markup (highlight / underline / strike out / squiggly) is applied through
/// the platform context menu, which uses `editing.color` for its colour.
/// The toolbar therefore exposes:
/// - Select, Pen, Text, Signature tools
/// - Color picker (sets `editing.color`)
/// - Save
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
              // Select tool
              IconButton(
                icon: const Icon(Icons.touch_app),
                color: _activeColor(
                  context,
                  editing.tool == PdfEditTool.select,
                ),
                onPressed: () => editing.tool = PdfEditTool.select,
                tooltip: 'Select',
              ),
              // Pen tool
              IconButton(
                icon: const Icon(Icons.edit),
                color: _activeColor(
                  context,
                  editing.tool == PdfEditTool.ink,
                ),
                onPressed: () => editing.tool = PdfEditTool.ink,
                tooltip: 'Pen',
              ),
              // Text tool
              IconButton(
                icon: const Icon(Icons.text_fields),
                color: _activeColor(
                  context,
                  editing.tool == PdfEditTool.freeText,
                ),
                onPressed: () => editing.tool = PdfEditTool.freeText,
                tooltip: 'Text',
              ),
              // Signature tool
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
              // Color picker — sets editing.color. The context-menu markup
              // (Highlight / Underline / Strike out / Squiggly) applies in
              // this color.
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
              // Save button
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