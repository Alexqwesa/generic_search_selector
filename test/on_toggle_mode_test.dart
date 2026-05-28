import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_search_selector/generic_search_selector.dart';

void main() {
  testWidgets('optimistic onToggle updates checkbox before gate completes', (
    tester,
  ) async {
    final gate = Completer<bool>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchAnchorPicker<int>(
            config: PickerConfig(
              loadItems: (_) async => [1, 2],
              idOf: (i) => i,
              labelOf: (i) => '$i',
              searchTermsOf: (_) => [],
            ),
            initialSelectedIds: const [],
            onToggleMode: OnToggleMode.optimistic,
            onToggle: (_, __) => gate.future,
            triggerBuilder: (_, open, __) => ElevatedButton(
              onPressed: open,
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.pump();

    final checkbox = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile).first,
    );
    expect(checkbox.value, true);

    gate.complete(false);
    await tester.pumpAndSettle();

    final reverted = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile).first,
    );
    expect(reverted.value, false);
  });

  testWidgets('awaitGate onToggle blocks checkbox until gate returns true', (
    tester,
  ) async {
    final gate = Completer<bool>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchAnchorPicker<int>(
            config: PickerConfig(
              loadItems: (_) async => [1, 2],
              idOf: (i) => i,
              labelOf: (i) => '$i',
              searchTermsOf: (_) => [],
            ),
            initialSelectedIds: const [],
            onToggle: (_, __) => gate.future,
            triggerBuilder: (_, open, __) => ElevatedButton(
              onPressed: open,
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.pump();

    var checkbox = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile).first,
    );
    expect(checkbox.value, false);

    gate.complete(true);
    await tester.pumpAndSettle();

    checkbox = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile).first,
    );
    expect(checkbox.value, true);
  });
}
