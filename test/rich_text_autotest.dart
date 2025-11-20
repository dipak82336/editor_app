import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:editor_app/models.dart';

void main() {
  group('Rich Text Logic Tests', () {
    test('Test 1: Apply global color -> Verify all text has style', () {
      final layer = TextLayer(
        id: '1',
        text: 'Hello World',
        style: TextStyle(color: Colors.black),
        selection: TextSelection.collapsed(offset: 0),
      );

      // Apply global style
      layer.applyStyle(TextStyle(color: Colors.red));

      // Verify base style is updated
      expect(layer.style.color, Colors.red);
      // Verify no spans created (global style shouldn't create spans ideally, or should cover everything)
      // My implementation keeps spans separate but updates base style if collapsed.
      expect(layer.spans.isEmpty, true);
    });

    test('Test 2: Apply range color -> Verify only range has style', () {
      final layer = TextLayer(
        id: '1',
        text: 'Hello World',
        style: TextStyle(color: Colors.black),
        selection: TextSelection(baseOffset: 0, extentOffset: 5), // Select "Hello"
      );

      // Apply range style
      layer.isEditing = true; // Simulate editing mode
      layer.applyStyle(TextStyle(color: Colors.blue));

      // Verify base style is NOT updated
      expect(layer.style.color, Colors.black);

      // Verify span created
      expect(layer.spans.length, 1);
      expect(layer.spans[0].start, 0);
      expect(layer.spans[0].end, 5);
      expect(layer.spans[0].style.color, Colors.blue);
    });

    test('Test 3: Index Shifting Logic (Insertion before)', () {
      final layer = TextLayer(
        id: '1',
        text: 'AB CDEF',
        spans: [StyleSpan(start: 3, end: 5, style: TextStyle(fontWeight: FontWeight.bold))], // "CD" is bold. Indices 3, 4. Range [3, 5)
      );

      // Insert "X" at 0. "XAB CDEF". CD is now at 4, 6.
      layer.shiftIndices(0, 1);

      expect(layer.spans.length, 1);
      expect(layer.spans[0].start, 4);
      expect(layer.spans[0].end, 6);
    });

    test('Test 4: Index Shifting Logic (Insertion inside)', () {
      final layer = TextLayer(
        id: '1',
        text: 'ABCDEF',
        spans: [StyleSpan(start: 2, end: 4, style: TextStyle(fontWeight: FontWeight.bold))], // "CD". Range [2, 4)
      );

      // Insert "X" at 3 (between C and D). "ABCXDEF".
      // Span was [2, 4). New span should be [2, 5).
      layer.shiftIndices(3, 1);

      expect(layer.spans.length, 1);
      expect(layer.spans[0].start, 2);
      expect(layer.spans[0].end, 5);
    });

    test('Test 5: Index Shifting Logic (Insertion after)', () {
       final layer = TextLayer(
        id: '1',
        text: 'ABCDEF',
        spans: [StyleSpan(start: 2, end: 4, style: TextStyle(fontWeight: FontWeight.bold))], // "CD". Range [2, 4)
      );

      // Insert "X" at 6. "ABCDEFX". Span should remain [2, 4).
      layer.shiftIndices(6, 1);

      expect(layer.spans.length, 1);
      expect(layer.spans[0].start, 2);
      expect(layer.spans[0].end, 4);
    });

    test('Test 6: Index Shifting Logic (Deletion before)', () {
      final layer = TextLayer(
        id: '1',
        text: 'XABCDEF',
        spans: [StyleSpan(start: 3, end: 5, style: TextStyle(fontWeight: FontWeight.bold))], // "CD". Range [3, 5)
      );

      // Delete "X" at 0. Length 1. Delta -1. "ABCDEF". Span becomes [2, 4).
      layer.shiftIndices(0, -1);

      expect(layer.spans.length, 1);
      expect(layer.spans[0].start, 2);
      expect(layer.spans[0].end, 4);
    });

    test('Test 7: Index Shifting Logic (Deletion overlapping start)', () {
       final layer = TextLayer(
        id: '1',
        text: 'ABCDEF',
        spans: [StyleSpan(start: 2, end: 4, style: TextStyle(fontWeight: FontWeight.bold))], // "CD". Range [2, 4)
      );

      // Delete "BC" at 1. Length 2. Delta -2.
      // Text was A B C D E F.
      // Indices: 0 1 2 3 4 5.
      // Span on [2, 4) -> C D.
      // Delete at 1, length 2. Removes B(1) and C(2).
      // Result text: A D E F.
      // New indices: A(0), D(1), E(2), F(3).
      // "C" was bold. "D" was bold.
      // "C" is deleted. "D" remains.
      // So new span should cover "D".
      // "D" was at 3, now at 1.
      // New span range [1, 2).

      layer.shiftIndices(1, -2);

      expect(layer.spans.length, 1);
      expect(layer.spans[0].start, 1);
      expect(layer.spans[0].end, 2);
    });

    test('Test 8: Index Shifting Logic (Deletion inside)', () {
       final layer = TextLayer(
        id: '1',
        text: 'ABCDEF',
        spans: [StyleSpan(start: 1, end: 5, style: TextStyle(fontWeight: FontWeight.bold))], // "BCDE". Range [1, 5)
      );

      // Delete "CD" at 2. Length 2. Delta -2.
      // Text: A B C D E F
      // Indices: 0 1 2 3 4 5
      // Span: 1-5 (B, C, D, E)
      // Delete 2, len 2 -> C, D removed.
      // Result: A B E F
      // Indices: 0 1 2 3
      // Remaining Bold: B, E.
      // B is at 1. E is at 2.
      // New Span: [1, 3).

      layer.shiftIndices(2, -2);

      expect(layer.spans.length, 1);
      expect(layer.spans[0].start, 1);
      expect(layer.spans[0].end, 3);
    });

    test('Test 9: Index Shifting Logic (Deletion completely covering span)', () {
       final layer = TextLayer(
        id: '1',
        text: 'ABCDEF',
        spans: [StyleSpan(start: 2, end: 4, style: TextStyle(fontWeight: FontWeight.bold))], // "CD". Range [2, 4)
      );

      // Delete "ABCDE" at 0. Length 5. Delta -5.
      // Span is gone.
      layer.shiftIndices(0, -5);

      expect(layer.spans.isEmpty, true);
    });

  });
}
