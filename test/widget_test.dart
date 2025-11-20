import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:editor_app/main.dart';
import 'package:editor_app/editor_canvas.dart';
import 'package:editor_app/models.dart';

void main() {
  testWidgets('Editor Core Interaction Test', (WidgetTester tester) async {
    // 0. Setup Screen Size to avoid FittedBox scaling issues
    tester.view.physicalSize = const Size(2000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Load the MyApp
    await tester.pumpWidget(const MyApp());

    // 2. Find the GestureDetector explicitly
    final gestureDetectorFinder = find.byKey(const Key('editor_gesture_detector'));
    expect(gestureDetectorFinder, findsOneWidget);

    // 3. Get the center of the gesture detector to interact with
    // Use the center of the render box to ensure we hit the widget logic correctly.
    final renderBox = tester.renderObject(gestureDetectorFinder) as RenderBox;
    final hitPoint = renderBox.localToGlobal(renderBox.size.center(Offset.zero));

    // --- TEST: TAP TO SELECT ---

    // Tap at the calculated center
    await tester.tapAt(hitPoint);
    await tester.pump(); // Rebuild to reflect state changes

    // Verify that the layer is selected
    // We access the state via the EditorCanvas widget (parent of GestureDetector)
    final canvasFinder = find.byType(EditorCanvas);
    final canvasWidget = tester.widget<EditorCanvas>(canvasFinder);
    final firstLayer = canvasWidget.composition.layers.first;

    expect(firstLayer.isSelected, isTrue, reason: "Layer should be selected after tapping.");

    // --- TEST: DRAG TO MOVE ---

    // We will drag the layer by 50, 50 pixels.
    const dragOffset = Offset(50, 50);
    final initialPosition = firstLayer.position;

    // Perform the drag gesture starting from the hit point
    await tester.dragFrom(hitPoint, dragOffset);
    await tester.pump(); // Rebuild

    // Verify the position has updated
    // Note: Flutter's Pan Gesture has a slop (hysteresis) of roughly 20 logical pixels
    // before it starts reporting drag events. This means the first ~20px of movement
    // are consumed to differentiate a tap from a drag.
    // Therefore, the actual movement will be roughly (50 - 20) = 30px.

    expect(
      firstLayer.position.dx,
      greaterThan(initialPosition.dx + 25.0),
      reason: "Layer X position did not update correctly (should move > 25px accounting for slop)",
    );

    expect(
      firstLayer.position.dy,
      greaterThan(initialPosition.dy + 25.0),
      reason: "Layer Y position did not update correctly (should move > 25px accounting for slop)",
    );
  });
}
