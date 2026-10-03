import 'package:flutter/material.dart';

enum AnnotationTool { select, highlight, pen, text, shape, signature, eraser }

enum AnnotationKind { highlight, penStroke, text, shape, signature }

class Annotation {
  final AnnotationKind kind;
  final int pageIndex;
  final Color color;
  final double strokeWidth;
  final List<Offset> points;   // normalized 0..1 coordinates
  final String? text;          // for text annotations
  final Rect? rect;            // for highlight/shape bounds

  Annotation({
    required this.kind,
    required this.pageIndex,
    required this.color,
    this.strokeWidth = 3,
    this.points = const [],
    this.text,
    this.rect,
  });
}