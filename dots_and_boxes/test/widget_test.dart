// test/widget_test.dart

// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dots_and_boxes/main.dart';

void main() {
  testWidgets('App shows correct title', (WidgetTester tester) async {
    // Build and render the app.
    await tester.pumpWidget(const DotsAndBoxesApp());
    // Wait for any animations/frames to finish.
    await tester.pumpAndSettle();

    // Verify the AppBar title is present.
    expect(find.text('Dots & Boxes'), findsOneWidget);
  });
}
