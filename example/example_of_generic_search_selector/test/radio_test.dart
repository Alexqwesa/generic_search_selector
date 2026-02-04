import 'package:example_of_generic_search_selector/main_radio.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Radio Picker: Single Selection', (WidgetTester tester) async {
    await tester.pumpWidget(const RadioDemoApp());
    await tester.pumpAndSettle();

    // 1. Open Basic Radio Picker
    final trigger = find.text('Select Main');
    expect(trigger, findsOneWidget);
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    // 2. Select "Main 1"
    final item1 = find.text('Main 1');
    expect(item1, findsOneWidget);
    await tester.tap(item1);
    await tester.pumpAndSettle();

    // Verify selection text update
    expect(find.text('Main: 1'), findsOneWidget);
    expect(find.text('Selected: 1'), findsOneWidget);

    // 3. Re-open and select "Main 2"
    await tester.tap(find.text('Main: 1'));
    await tester.pumpAndSettle();

    final item2 = find.text('Main 2');
    await tester.tap(item2);
    await tester.pumpAndSettle();

    // Verify selection changed
    expect(find.text('Main: 2'), findsOneWidget);
    expect(find.text('Selected: 2'), findsOneWidget);
  });

  testWidgets('Radio Picker: Sub Picker Selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RadioDemoApp());
    await tester.pumpAndSettle();

    // 1. Open Parent Picker with Sub
    await tester.tap(find.text('Open Parent with Sub'));
    await tester.pumpAndSettle();

    // 2. Open Sub Picker
    await tester.tap(find.text('Sub Radio Trigger (Tile)'));
    await tester.pumpAndSettle();

    // 3. Select "Sub 1"
    final subItem1 = find.text('Sub 1');
    expect(subItem1, findsOneWidget);
    await tester.tap(subItem1);
    await tester.pumpAndSettle();

    // Verify sub selection updated on main screen
    expect(find.text('Sub Selected: 10'), findsOneWidget);
  });

  testWidgets('Radio Picker: Parent Selection with Sub', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RadioDemoApp());
    await tester.pumpAndSettle();

    // 1. Open Parent Picker with Sub
    final trigger = find.text('Open Parent with Sub');
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    // 2. Select "Main 2"
    final item2 = find.text('Main 2');
    expect(item2, findsOneWidget);
    await tester.tap(item2);
    await tester.pumpAndSettle();

    // Verify selection updated on trigger button
    // The current implementation is static ('Open Parent with Sub'), so this should fail if we expect dynamics.
    // We expect it to show 'Main: 2' or similar if it worked like the first picker.
    // The prompt says "it change in list but not on the main screen".
    // So let's assert that the text changes to "Parent: 2" (we will implement this).
    expect(find.text('Parent: 2'), findsOneWidget);
  });
}
