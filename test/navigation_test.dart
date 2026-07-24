import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newron/main.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('switching categories loads and selects the requested section', (
    tester,
  ) async {
    final repository = FakeNewsRepository();
    await tester.pumpWidget(
      NewronApp(
        repository: repository,
        aiAssistant: FakeAiAssistant(),
        cache: MemoryDigestCache(),
        settingsStore: MemorySettingsStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('World'));
    await tester.pumpAndSettle();

    final worldChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'World'),
    );
    expect(worldChip.selected, isTrue);
    expect(repository.calls, ['Top Stories', 'World']);
    expect(find.text('World documented report 1'), findsOneWidget);
  });

  testWidgets('changing the AI model persists a concrete selection', (
    tester,
  ) async {
    final settings = MemorySettingsStore();
    await tester.pumpWidget(
      NewronApp(
        repository: FakeNewsRepository(),
        aiAssistant: FakeAiAssistant(),
        cache: MemoryDigestCache(),
        settingsStore: settings,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Test Model'), findsOneWidget);

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdown.initialValue, 'test/model:free');
  });
}
