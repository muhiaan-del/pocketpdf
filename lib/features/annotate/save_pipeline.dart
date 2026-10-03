import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'annotation_model.dart';

class SavePipeline {
  static Future<String> saveWithAnnotations({
    required String sourcePath,
    required List<Annotation> annotations,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = sourcePath.split(Platform.pathSeparator).last.replaceAll('.pdf', '');

    // 1. Copy original PDF
    final outPdf = File('${dir.path}/${baseName}_annotated_$stamp.pdf');
    await File(sourcePath).copy(outPdf.path);

    // 2. Write annotations sidecar (v1 placeholder until M2-23)
    final sidecar = File('${outPdf.path}.annotations.json');
    await sidecar.writeAsString(jsonEncode(annotations.map((a) => {
      'kind': a.kind.name,
      'page': a.pageIndex,
      'color': a.color.value,
      'strokeWidth': a.strokeWidth,
      'points': a.points.map((p) => [p.dx, p.dy]).toList(),
      'rect': a.rect == null ? null : [a.rect!.left, a.rect!.top, a.rect!.right, a.rect!.bottom],
      'text': a.text,
    }).toList()));

    return outPdf.path;
  }
}