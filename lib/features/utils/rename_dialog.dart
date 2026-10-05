import 'package:flutter/material.dart';

class RenameDialog extends StatefulWidget {
  final String initialName;
  const RenameDialog({super.key, required this.initialName});

  static Future<String?> show(BuildContext context, String initialName) {
    return showDialog<String>(
      context: context,
      builder: (_) => RenameDialog(initialName: initialName),
    );
  }

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final base = widget.initialName.replaceAll('.pdf', '');
    _controller = TextEditingController(text: base);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: base.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename file'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'File name',
          suffixText: '.pdf',
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Rename'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, '$name.pdf');
  }
}