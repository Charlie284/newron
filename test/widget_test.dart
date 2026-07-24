import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newron/main.dart';

import 'support/fakes.dart';

void main() {
  late FakeNewsRepository repository;
  late FakeAiAssistant assistant;

  setUp(() {
    repository = FakeNewsRepository();
    assistant = FakeAiAssistant();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      NewronApp(
        repository: repository,
        aiAssistant: assistant,
        cache: MemoryDigestCache(),
        settingsStore: MemorySettingsStore(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders linked coverage without running AI on startup', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('NEWRON'), findsOneWidget);
    expect(find.text('Coverage'), findsOneWidget);
    expect(find.text('Generate AI brief'), findsOneWidget);
    expect(find.text('Read original'), findsNWidgets(6));
    expect(find.text('Explore'), findsNWidgets(6));
    expect(assistant.createBriefCalls, 0);
  });

  testWidgets('header controls have names and minimum touch targets', (
    tester,
  ) async {
    await pumpApp(tester);

    for (final tooltip in ['Refresh coverage', 'Open settings']) {
      final finder = find.byTooltip(tooltip);
      expect(finder, findsOneWidget);
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('AI brief is explicit, grounded, and fact-checkable', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Generate AI brief'));
    await tester.pumpAndSettle();

    expect(assistant.createBriefCalls, 1);
    expect(find.text('Regenerate AI brief'), findsOneWidget);
    expect(find.text('Cited reporting'), findsOneWidget);
    expect(
      find.textContaining('AI synthesis from the linked articles'),
      findsOneWidget,
    );

    await tester.tap(find.text('Fact check'));
    await tester.pumpAndSettle();

    expect(assistant.factCheckCalls, 1);
    expect(
      find.textContaining('supported by the cited supplied report'),
      findsOneWidget,
    );
  });

  testWidgets('provider failure is labeled and remains a source-only view', (
    tester,
  ) async {
    assistant.useModelInference = false;
    await pumpApp(tester);

    await tester.tap(find.text('Generate AI brief'));
    await tester.pumpAndSettle();

    expect(find.text('Generate AI brief'), findsOneWidget);
    expect(
      find.textContaining('Showing a source-only fallback'),
      findsOneWidget,
    );
    expect(
      find.textContaining('AI synthesis from the linked articles'),
      findsNothing,
    );
    final factCheck = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Fact check'),
    );
    expect(factCheck.onPressed, isNull);
  });

  testWidgets('compact width keeps settings and model control usable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Model used for opt-in analysis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Explore requires a meaningful question before submission', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('Explore').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore').first);
    await tester.pumpAndSettle();

    FilledButton analyzeButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Analyze supplied report'),
    );

    expect(analyzeButton().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Why');
    await tester.pump();
    expect(analyzeButton().onPressed, isNull);
    expect(find.text('Enter at least 4 characters.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Why now?');
    await tester.pump();
    expect(analyzeButton().onPressed, isNotNull);
  });

  testWidgets('main feed uses clamped scrolling to avoid blank overscroll', (
    tester,
  ) async {
    await pumpApp(tester);

    final scrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    expect(scrollView.physics, isA<ClampingScrollPhysics>());
  });
}
