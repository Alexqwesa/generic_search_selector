import 'package:example_of_generic_search_selector/main_radio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Radio Picker: Single Selection', (WidgetTester tester) async {
    await tester.pumpWidget(const RadioDemoApp());
    await tester.pumpAndSettle();

    // 1. Open Basic Radio Picker
    final trigger = find.byTooltip('Open radio picker');
    expect(trigger, findsOneWidget);
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    // 2. Select "Main 1"
    final item1 = find.text('Main 1');
    expect(item1, findsOneWidget);
    await tester.tap(item1);
    await tester.pumpAndSettle();

    // Verify selection text update (Chip)
    expect(find.text('Main 1'), findsOneWidget);
    // Title of the card
    expect(find.text('Selected Main Item'), findsOneWidget);

    // 3. Re-open and select "Main 2"
    await tester.tap(trigger); // Open again
    await tester.pumpAndSettle();

    final item2 = find.text('Main 2');
    await tester.tap(item2);
    await tester.pumpAndSettle();

    // Verify selection changed
    expect(find.text('Main 2'), findsOneWidget);
  });

  testWidgets('Radio Picker: Sub Picker Selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RadioDemoApp());
    await tester.pumpAndSettle();

    // 1. Open Parent Picker with Sub
    final parentTrigger = find.byTooltip('Open parent picker');
    await tester.tap(parentTrigger);
    await tester.pumpAndSettle();

    // 2. Open Sub Picker (inside parent overlay)
    // The sub picker trigger is a ListTile with title 'Sub Radio Trigger (Tile)'
    await tester.tap(find.text('Sub Radio Trigger (Tile)'));
    await tester.pumpAndSettle();

    // 3. Select "Sub 1"
    final subItem1 = find.text('Sub 1');
    expect(subItem1, findsOneWidget);
    await tester.tap(subItem1);
    await tester.pumpAndSettle();

    // Verify sub selection updated on main screen (Chip)
    expect(find.text('Sub 1'), findsOneWidget);

    // Also check title
    expect(find.text('Selected Parent/Sub Item'), findsOneWidget);
  });

  testWidgets('Radio Picker: Parent Selection with Sub', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RadioDemoApp());
    await tester.pumpAndSettle();

    // 1. Open Parent Picker with Sub
    final trigger = find.byTooltip('Open parent picker');
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    // 2. Select "Main 2"
    final item2 = find.text('Main 2');
    expect(item2, findsOneWidget);
    await tester.tap(item2);
    await tester.pumpAndSettle();

    // Verify selection updated (Chip)
    expect(find.text('Main 2'), findsOneWidget);
  });
}
