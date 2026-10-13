import 'dart:io';
import 'package:flutter/material.dart';

class WindowsLanguagePrompt {
  /// Opens Windows Settings to the Language & region page.
  ///
  /// Uses `ms-settings:regionlanguage` — the correct URI for
  /// Time & language → Language & region [citation:10].
  static Future<bool> openLanguageSettings() async {
    try {
      await Process.run(
        'cmd',
        ['/c', 'start', 'ms-settings:regionlanguage'],
        runInShell: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shows a dialog explaining that a language pack is needed,
  /// with a button to open Windows Settings.
  ///
  /// Returns true if the user chose to open Settings.
  static Future<bool> show(BuildContext context, String languageName) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OCR language not installed'),
        content: Text(
          'Windows needs the language pack for OCR in $languageName.\n\n'
          'Tap "Open Settings" and add the language under '
          '"Preferred languages". Windows will download the OCR pack '
          'automatically.\n\n'
          'Note: Some Windows editions (Single Language) cannot add '
          'languages. On those systems, OCR works only in the system '
          'language.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await openLanguageSettings();
    }
    return shouldOpen == true;
  }
}