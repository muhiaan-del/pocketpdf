import 'package:flutter/material.dart';
import 'annotation_model.dart';

class AnnotationLayer extends StatefulWidget {
  final AnnotationTool tool;
  final Color color;
  final List<Annotation> annotations;
  final ValueChanged<Annotation> onAnnotationAdded;

  const AnnotationLayer({
    super.key,
    required this.tool,
    required this.color,
    required this.annotations,
    required this.onAnnotationAdded,
  });

  @override
  State<AnnotationLayer> createState() => _AnnotationLayerState();
}

class _AnnotationLayerState extends State<AnnotationLayer> {
  final _current = <Offset>[];
  Rect? _dragRect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) {
        if (widget.tool == AnnotationTool.pen) {
          setState(() => _current
            ..clear()
            ..add(d.localPosition));
        } else if (widget.tool == AnnotationTool.highlight ||
            widget.tool == AnnotationTool.shape) {
          setState(() => _dragRect = Rect.fromPoints(d.localPosition, d.localPosition));
        }
      },
      onPanUpdate: (d) {
        if (widget.tool == AnnotationTool.pen) {
          setState(() => _current.add(d.localPosition));
        } else if (_dragRect != null) {
          setState(() => _dragRect = Rect.fromPoints(_dragRect!.topLeft, d.localPosition));
        }
      },
      onPanEnd: (_) {
        final size = context.size ?? Size.zero;
        if (widget.tool == AnnotationTool.pen && _current.isNotEmpty) {
          widget.onAnnotationAdded(Annotation(
            kind: AnnotationKind.penStroke,
            pageIndex: 0,
            color: widget.color,
            points: _current.map((p) => Offset(p.dx / size.width, p.dy / size.height)).toList(),
          ));
        } else if (widget.tool == AnnotationTool.highlight && _dragRect != null) {
          widget.onAnnotationAdded(Annotation(
            kind: AnnotationKind.highlight,
            pageIndex: 0,
            color: widget.color.withOpacity(0.4),
            rect: Rect.fromLTRB(
              _dragRect!.left / size.width,
              _dragRect!.top / size.height,
              _dragRect!.right / size.width,
              _dragRect!.bottom / size.height,
            ),
          ));
        } else if (widget.tool == AnnotationTool.shape && _dragRect != null) {
          widget.onAnnotationAdded(Annotation(
            kind: AnnotationKind.shape,
            pageIndex: 0,
            color: widget.color,
            rect: Rect.fromLTRB(
              _dragRect!.left / size.width,
              _dragRect!.top / size.height,
              _dragRect!.right / size.width,
              _dragRect!.bottom / size.height,
            ),
          ));
        }
        setState(() {
          _current.clear();
          _dragRect = null;
        });
      },
      child: CustomPaint(
        painter: _AnnotationPainter(
          annotations: widget.annotations,
          current: _current,
          dragRect: _dragRect,
          color: widget.color,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<Annotation> annotations;
  final List<Offset> current;
  final Rect? dragRect;
  final Color color;

  _AnnotationPainter({
    required this.annotations,
    required this.current,
    required this.dragRect,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final a in annotations) {
      final paint = Paint()
        ..color = a.color
        ..strokeWidth = a.strokeWidth
        ..style = a.kind == AnnotationKind.penStroke ? PaintingStyle.stroke : PaintingStyle.fill;

      if (a.kind == AnnotationKind.penStroke) {
        final path = Path();
        for (var i = 0; i < a.points.length; i++) {
          final p = Offset(a.points[i].dx * size.width, a.points[i].dy * size.height);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      } else if (a.rect != null) {
        final r = Rect.fromLTRB(
          a.rect!.left * size.width, a.rect!.top * size.height,
          a.rect!.right * size.width, a.rect!.bottom * size.height,
        );
        canvas.drawRect(r, paint);
      }
    }

    // live pen stroke
    if (current.isNotEmpty) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(current.first.dx, current.first.dy);
      for (final p in current.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    // live rect
    if (dragRect != null) {
      final paint = Paint()
        ..color = color.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      canvas.drawRect(dragRect!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter old) => true;
}