import 'package:flutter/material.dart';
import 'dart:ui' as ui;

// Constants
const double handleRadius = 9.0;
const double rotationHandleDistance = 30.0;

class EditorComposition {
  Size dimension;
  Color backgroundColor;
  List<BaseLayer> layers;

  EditorComposition({
    required this.dimension,
    this.backgroundColor = Colors.white,
    List<BaseLayer>? layers,
  }) : layers = layers ?? [];
}

abstract class BaseLayer {
  String id;
  Offset position;
  double rotation;
  double scale;
  bool isSelected;
  bool isEditing;

  BaseLayer({
    required this.id,
    this.position = Offset.zero,
    this.rotation = 0.0,
    this.scale = 1.0,
    this.isSelected = false,
    this.isEditing = false,
  });

  Matrix4 get matrix {
    final mat = Matrix4.identity();
    mat.setTranslationRaw(position.dx, position.dy, 0);
    mat.rotateZ(rotation);
    mat.scale(scale, scale, 1.0);
    return mat;
  }

  void paint(Canvas canvas, Size size);
  Size get size;
}

class StyleSpan {
  int start;
  int end;
  TextStyle style;

  StyleSpan({required this.start, required this.end, required this.style});

  StyleSpan copyWith({int? start, int? end, TextStyle? style}) {
    return StyleSpan(
      start: start ?? this.start,
      end: end ?? this.end,
      style: style ?? this.style,
    );
  }

  @override
  String toString() => 'StyleSpan($start, $end, $style)';
}

class TextLayer extends BaseLayer {
  String text;
  TextStyle style;
  List<StyleSpan> spans;
  Size _cachedSize = Size.zero;

  TextSelection selection;
  bool showCursor;

  TextLayer({
    required super.id,
    required this.text,
    super.position,
    super.rotation,
    super.scale,
    this.style = const TextStyle(fontSize: 30, color: Colors.black),
    List<StyleSpan>? spans,
    this.selection = const TextSelection.collapsed(offset: 0),
    this.showCursor = false,
  }) : spans = spans ?? [];

  @override
  Size get size => _cachedSize;

  /// Shifts the indices of the StyleSpans when text is inserted or deleted.
  /// [index] is the insertion/deletion point.
  /// [delta] is the number of characters added (positive) or removed (negative).
  void shiftIndices(int index, int delta) {
    final newSpans = <StyleSpan>[];

    for (var span in spans) {
      // Case 1: Modification happens strictly after the span. Span is untouched.
      if (index >= span.end) {
        newSpans.add(span);
        continue;
      }

      // Case 2: Modification happens strictly before the span. Shift both indices.
      if (index <= span.start) {
        // If deletion overlaps the span start?
        // Wait, if index <= span.start, then:
        // If insertion (delta > 0): shift both start and end by delta.
        // If deletion (delta < 0):
        //   If deletion range [index, index - delta] covers the span start?
        //   Let's handle logic more carefully.

        // Logic based on the "index shifting" request:
        // "Handle insertion before, inside, and after spans."
        // "Handle deletion overlapping spans."

        int newStart = span.start;
        int newEnd = span.end;

        if (delta > 0) {
          // Insertion
          if (index <= span.start) {
            newStart += delta;
            newEnd += delta;
          } else if (index < span.end) {
             // Insertion Inside
             newEnd += delta;
          }
        } else {
          // Deletion (delta is negative)
          // Deleted range is [index, index + abs(delta))
          int deleteEnd = index + delta.abs();

          // Adjust Start
          if (span.start >= index) {
              if (span.start < deleteEnd) {
                  newStart = index; // Collapsed into deletion point
              } else {
                  newStart += delta; // Shift left
              }
          }

          // Adjust End
          if (span.end > index) {
              if (span.end <= deleteEnd) {
                  newEnd = index; // Collapsed into deletion point
              } else {
                  newEnd += delta; // Shift left
              }
          }
        }

        // Only keep span if it still has length
        if (newEnd > newStart) {
           newSpans.add(StyleSpan(start: newStart, end: newEnd, style: span.style));
        }

        continue; // We handled this span
      }

      // Case 3: Modification inside the span
      if (index > span.start && index < span.end) {
          if (delta > 0) {
             // Insertion inside
             newSpans.add(StyleSpan(start: span.start, end: span.end + delta, style: span.style));
          } else {
             // Deletion inside
             // deletion range [index, index + abs(delta))
             // Since index < span.end, the deletion starts inside.
             // The new end will be reduced by how much of the deletion is inside the span.

             int deleteLen = delta.abs();
             // Effective deletion within this span
             int effectiveDelete = 0;
             if (index + deleteLen <= span.end) {
                effectiveDelete = deleteLen;
             } else {
                effectiveDelete = span.end - index;
             }

             int newEnd = span.end - effectiveDelete;
             if (newEnd > span.start) {
                 newSpans.add(StyleSpan(start: span.start, end: newEnd, style: span.style));
             }
          }
      }
    }

    spans = newSpans;
  }

  /// Applies a style.
  /// If selection is collapsed, update the global style.
  /// If range is selected, add a new StyleSpan.
  void applyStyle(TextStyle newStyle) {
      if (!isEditing || selection.isCollapsed) {
          // Apply to entire text
          style = style.merge(newStyle);
          // When applying global style, should we clear spans?
          // The prompt says: "Apply the chosen style to the Entire Text (Global Update)."
          // Usually this implies setting the base style. Existing spans might override it or merge with it.
          // To be simple and robust, we can keep spans but they will be rendered on top of base style.
          // Or we could clear spans if the user wants to reset everything.
          // "Global Update" usually implies base style update. I will keep spans.
      } else {
          // Apply to range
          int start = selection.start;
          int end = selection.end;
          if (start < 0) start = 0;
          if (end > text.length) end = text.length;

          if (start < end) {
              // Remove overlapping parts of existing spans to avoid mess?
              // Or just stack them? The prompt says "Create a new StyleSpan".
              // Let's try to keep it clean: If we add a span on top, we should probably
              // handle overlaps, but for step 1 let's just add it.
              // A more robust implementation would flatten overlaps, but let's start simple.
              // Actually, if I just add it, I need to make sure the painter renders them in order
              // or processes them.
              // Ideally, we should remove underlying styles in this range or split them.
              // But "Rich Text" usually allows nested spans. Flutter's TextSpan allows hierarchy.
              // However, my structure is a flat list `List<StyleSpan>`.
              // So I should probably split existing spans if they overlap with the new one.

              _addSpan(start, end, newStyle);
          }
      }
  }

  void _addSpan(int start, int end, TextStyle newStyle) {
      // Simple approach for now: just add it.
      // The painter will need to handle overlaps or we assume last one wins.
      // To prevent infinite growth, we should ideally merge same-styled adjacent spans.

      // Better approach:
      // Remove any existing span coverage in this range, then add new one.

      List<StyleSpan> processedSpans = [];

      for (var span in spans) {
          // No overlap
          if (span.end <= start || span.start >= end) {
              processedSpans.add(span);
          } else {
              // Overlap
              // 1. Part before the new range
              if (span.start < start) {
                  processedSpans.add(StyleSpan(start: span.start, end: start, style: span.style));
              }

              // 2. Part after the new range
              if (span.end > end) {
                  processedSpans.add(StyleSpan(start: end, end: span.end, style: span.style));
              }

              // The middle part is replaced by the new span (implicit, by not adding the old middle)
          }
      }

      processedSpans.add(StyleSpan(start: start, end: end, style: newStyle));
      // Sort by start index
      processedSpans.sort((a, b) => a.start.compareTo(b.start));

      spans = processedSpans;
  }

  TextSpan _buildTextSpan() {
      if (text.isEmpty) return TextSpan(text: "", style: style);
      if (spans.isEmpty) return TextSpan(text: text, style: style);

      // We need to flatten the spans into a continuous list of TextSpans
      // The base text is covered by `style`.
      // Spans cover specific ranges.

      List<TextSpan> children = [];
      int currentIndex = 0;

      // Sort spans just in case
      spans.sort((a, b) => a.start.compareTo(b.start));

      for (var span in spans) {
          if (span.start > currentIndex) {
              // Add un-spanned text
              children.add(TextSpan(
                  text: text.substring(currentIndex, span.start),
                  style: style
              ));
          }

          // Add spanned text
          // Note: If spans overlap, this simple loop fails.
          // My `_addSpan` logic ensures they don't overlap (it splits them).
          // So we can assume non-overlapping, flat list.

          int safeEnd = span.end > text.length ? text.length : span.end;
          if (span.start < text.length) {
             children.add(TextSpan(
                text: text.substring(span.start, safeEnd),
                style: style.merge(span.style)
             ));
          }

          currentIndex = safeEnd;
      }

      if (currentIndex < text.length) {
          children.add(TextSpan(
              text: text.substring(currentIndex),
              style: style
          ));
      }

      return TextSpan(children: children);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: _buildTextSpan(),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    _cachedSize = textPainter.size;

    final paintOffset = Offset(-_cachedSize.width / 2, -_cachedSize.height / 2);

    // 1. Draw Selection Highlights
    if (isEditing) {
      final selectionColor = Colors.blue.withOpacity(0.3);
      final safeSelection = TextSelection(
        baseOffset: selection.baseOffset.clamp(0, text.length),
        extentOffset: selection.extentOffset.clamp(0, text.length),
      );

      if (!safeSelection.isCollapsed) {
        final boxes = textPainter.getBoxesForSelection(safeSelection);
        for (var box in boxes) {
          final rect = box.toRect().shift(paintOffset);
          canvas.drawRect(rect, Paint()..color = selectionColor);
        }
      }
    }

    // 2. Draw Text
    textPainter.paint(canvas, paintOffset);

    // 3. Draw Cursor
    if (isEditing && showCursor && selection.isCollapsed) {
      final safeOffset = selection.baseOffset.clamp(0, text.length);
      final caretOffset = textPainter.getOffsetForCaret(
        TextPosition(offset: safeOffset),
        Rect.zero,
      );
      final cursorHeight = text.isEmpty
          ? (style.fontSize ?? 30)
          : textPainter.preferredLineHeight;

      final p1 = paintOffset + caretOffset;
      final p2 = p1 + Offset(0, cursorHeight);

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Colors.blueAccent
          ..strokeWidth = 2,
      );
    }

    // 4. Draw UI Border & Handles
    if (isSelected) {
      final rect = paintOffset & _cachedSize;

      final borderPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / scale;

      _drawDashedRect(canvas, rect, borderPaint);

      final handleFill = Paint()..color = Colors.white;
      final handleStroke = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / scale;
      final radius = handleRadius / scale;

      final corners = [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ];
      for (var point in corners) {
        canvas.drawCircle(point, radius, handleFill);
        canvas.drawCircle(point, radius, handleStroke);
      }

      final topCenter = rect.topCenter;
      final rotPos = Offset(
        topCenter.dx,
        topCenter.dy - (rotationHandleDistance / scale),
      );
      canvas.drawLine(topCenter, rotPos, borderPaint);
      canvas.drawCircle(rotPos, radius, handleFill);
      canvas.drawCircle(rotPos, radius, handleStroke);
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addRect(rect);
    final dashWidth = 10.0 / scale;
    final dashSpace = 5.0 / scale;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }
}
