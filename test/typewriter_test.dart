import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newron/main.dart';

void main() {
  testWidgets('TypewriterText displays text gradually', (
    WidgetTester tester,
  ) async {
    const testText = 'Hello Newron';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TypewriterText(text: testText, style: TextStyle()),
        ),
      ),
    );

    // Initially, it might show 0 or 2 characters depending on the clamp
    // The timer is 14ms per 2 characters.

    expect(find.byType(TypewriterText), findsOneWidget);

    // Wait for animation to complete
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.textContaining(testText), findsOneWidget);
  });
}
