import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:newron/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const NewronApp());
    await tester.pump();
  }

  group('NewronApp', () {
    testWidgets('renders the core briefing shell', (WidgetTester tester) async {
      await pumpApp(tester);

      expect(find.text('NEWRON'), findsOneWidget);
      expect(find.text('Top Stories'), findsAtLeastNWidgets(2));
      expect(find.text('Top Stories • Center'), findsNothing);
      expect(find.textContaining('Bias slider:'), findsNothing);
      expect(find.byType(ChoiceChip), findsAtLeastNWidgets(5));
      expect(find.text('World'), findsOneWidget);
      expect(find.text('Politics'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
      expect(
        find.text(
          'Live sources could not be reached. Check the connection and refresh again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows summary action controls in the loading state', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      final sourcesButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Sources'),
      );
      final factCheckButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Fact check'),
      );

      expect(sourcesButton.onPressed, isNull);
      expect(factCheckButton.onPressed, isNull);
    });

    testWidgets('opens the full settings sheet', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Briefing'), findsOneWidget);
      expect(find.text('AI model'), findsOneWidget);
      expect(find.text('Bias lens'), findsOneWidget);
      expect(find.text('Center'), findsWidgets);
      expect(find.text('Refresh now'), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Light'), findsOneWidget);

      await tester.drag(find.byType(ListView).last, const Offset(0, -700));
      await tester.pumpAndSettle();

      expect(find.text('Data'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Clear local cache'), findsOneWidget);
    });

    testWidgets('theme toggle updates the header icon', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.light_mode_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_rounded), findsNothing);
    });
  });
}
