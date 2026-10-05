import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

class SaveService {
  static Future<String?> savePdf(Uint8List bytes, String fileName) async {
    try {
      if (Platform.isAndroid) {
        final downloads = Directory('/storage/emulated/0/Download/PocketPDF');
        if (!await downloads.exists()) {
          await downloads.create(recursive: true);
        }
        final out = File(p.join(downloads.path, fileName));
        await out.writeAsBytes(bytes, flush: true);
        return out.path;
      } else if (Platform.isWindows) {
        final home = Platform.environment['USERPROFILE'] ?? '';
        final dir = Directory(p.join(home, 'Documents', 'PocketPDF'));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final out = File(p.join(dir.path, fileName));
        await out.writeAsBytes(bytes, flush: true);
        return out.path;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}