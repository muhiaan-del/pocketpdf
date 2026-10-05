import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'image_to_pdf.dart';

class ImagesToPdfScreen extends StatefulWidget {
  const ImagesToPdfScreen({super.key});

  @override
  State<ImagesToPdfScreen> createState() => _ImagesToPdfScreenState();
}

class _ImagesToPdfScreenState extends State<ImagesToPdfScreen> {
  bool _busy = false;

  Future<List<String>> _pickImagePaths() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      return images.map((x) => x.path).toList();
    } else {
      // Windows, macOS, Linux — file_picker v13 returns List<PlatformFile>
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      return result
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
    }
  }

  Future<void> _pickImages() async {
    setState(() => _busy = true);
    try {
      final paths = await _pickImagePaths();
      if (paths.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final pdfBytes = await ImageToPdf.convertImagesToPdf(paths);

      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(pdfBytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Images to PDF')),
      body: Center(
        child: _busy
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image, size: 96),
                    const SizedBox(height: 24),
                    const Text(
                      'Convert images to PDF',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick one or more images from your gallery.\n'
                      'They will be combined into a single PDF.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Pick Images'),
                      onPressed: _pickImages,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}