import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_search_selector/generic_search_selector.dart';

void main() {
  testWidgets('SubPickerTile syncs removals but not additions', (tester) async {
    final parentPending = ValueNotifier<Set<int>>({1, 2, 3});
    // Mock parent actions
    final parentActions = PickerActions<int>(
      pendingN: parentPending,
      idOf: (i) => i,
      close: ([_]) {},
      mode: PickerMode.multi,
      getKey: (_) => GlobalKey(),
      refresh: () {},
    );

    int finishCallCount = 0;
    List<int> lastAdded = [];
    List<int> lastRemoved = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubPickerTile<int>(
            title: 'Sub Picker',
            config: PickerConfig(
              loadItems: (_) async => [1, 2, 3, 4, 5],
              idOf: (i) => i,
              labelOf: (i) => '$i',
              searchTermsOf: (_) => [],
            ),
            initialSelectedIds: const [
              1,
              2,
            ], // 1, 2 are selected in sub-picker (present in main)
            parentActions: parentActions,
            onFinish: (ids, {required added, required removed}) async {
              finishCallCount++;
              lastAdded = added;
              lastRemoved = removed;
            },
          ),
        ),
      ),
    );

    // Open the sub-picker
    await tester.tap(find.text('Sub Picker'));
    await tester.pumpAndSettle();

    // Verify initial state in overlay: 1, 2 selected.
    // We want to ADD 4 and REMOVE 2.
    // 4 is NOT in parentPending.
    // 2 IS in parentPending.

    // Tap 4 (select it) -> added
    await tester.tap(find.text('4'));
    await tester.pump();

    // Tap 2 (deselect it) -> removed
    await tester.tap(find.text('2'));
    await tester.pump();

    // Close the picker (back button or close)
    // Finding the back button in SearchAnchor/SearchController view is tricky as it's built-in.
    // We can simulate close by finding the back button.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(finishCallCount, 1);
    expect(lastAdded, [4]);
    expect(lastRemoved, [2]);

    // CHECK PARENT ACTIONS BEHAVIOR
    // 1. Removed item (2) should be removed from parentPending.
    expect(
      parentPending.value.contains(2),
      false,
      reason: 'Removed item 2 should be removed from parent',
    );

    // 2. Added item (4) should NOT be added to parentPending (per "default they added as not selected").
    expect(
      parentPending.value.contains(4),
      false,
      reason: 'Added item 4 should NOT be auto-selected in parent',
    );

    // 3. Unchanged item (1) should remain in parentPending
    expect(parentPending.value.contains(1), true);
    expect(
      parentPending.value.contains(3),
      true,
    ); // 3 was not involved in sub-picker
  });

  testWidgets('SubPickerTile uses triggerBuilder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubPickerTile<int>(
            title: 'I am ignored',
            config: PickerConfig(
              loadItems: (_) async => [1],
              idOf: (i) => i,
              labelOf: (i) => '$i',
              searchTermsOf: (_) => [],
            ),
            initialSelectedIds: const [],
            triggerBuilder: (context, open, tick) {
              return ElevatedButton(
                onPressed: open,
                child: Text('Custom Trigger $tick'),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('I am ignored'), findsNothing);
    expect(find.text('Custom Trigger 0'), findsOneWidget);

    await tester.tap(find.text('Custom Trigger 0'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('SubPickerTile uses itemBuilder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubPickerTile<int>(
            title: 'Sub Picker',
            config: PickerConfig(
              loadItems: (_) async => [1, 2],
              idOf: (i) => i,
              labelOf: (i) => '$i',
              searchTermsOf: (_) => [],
            ),
            initialSelectedIds: const [],
            itemBuilder: (context, item, isSelected, onToggle) {
              return ListTile(
                title: Text('Custom Item $item'),
                selected: isSelected,
                onTap: onToggle,
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sub Picker'));
    await tester.pumpAndSettle();

    expect(find.text('Custom Item 1'), findsOneWidget);
    expect(find.text('Custom Item 2'), findsOneWidget);

    await tester.tap(find.text('Custom Item 1'));
    await tester.pump();
  });
}
