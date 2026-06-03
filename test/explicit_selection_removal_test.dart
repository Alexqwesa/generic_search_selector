import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_search_selector/generic_search_selector.dart';

void main() {
  testWidgets(
    'partial results preserve unseen selections and report only explicit unselects',
    (tester) async {
      List<int> finalIds = [];
      List<int> addedIds = [];
      List<int> removedIds = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchAnchorPicker<int>(
              config: PickerConfig<int>(
                loadItems: (_) async => [2, 4],
                idOf: (i) => i,
                labelOf: (i) => 'Item $i',
                searchTermsOf: (i) => ['Item $i'],
              ),
              initialSelectedIds: const [1, 2, 3],
              triggerBuilder: (_, open, __) =>
                  ElevatedButton(onPressed: open, child: const Text('Open')),
              onFinish: ({required added, required removed}) async {
                addedIds = added;
                removedIds = removed;
              },
              onFinishReplaceAll: (ids) async {
                finalIds = ids;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Item 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(finalIds.toSet(), {1, 3});
      expect(addedIds, isEmpty);
      expect(removedIds, [2]);
    },
  );

  testWidgets('user row checks are reported as added', (tester) async {
    List<int> finalIds = [];
    List<int> addedIds = [];
    List<int> removedIds = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchAnchorPicker<int>(
            config: PickerConfig<int>(
              loadItems: (_) async => [2, 4],
              idOf: (i) => i,
              labelOf: (i) => 'Item $i',
              searchTermsOf: (i) => ['Item $i'],
            ),
            initialSelectedIds: const [1, 2, 3],
            triggerBuilder: (_, open, __) =>
                ElevatedButton(onPressed: open, child: const Text('Open')),
            onFinish: ({required added, required removed}) async {
              addedIds = added;
              removedIds = removed;
            },
            onFinishReplaceAll: (ids) async {
              finalIds = ids;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Item 4'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(finalIds.toSet(), {1, 2, 3, 4});
    expect(addedIds, [4]);
    expect(removedIds, isEmpty);
  });

  testWidgets(
    'closing partial results without toggles preserves all selected ids',
    (tester) async {
      List<int> finalIds = [];
      List<int> removedIds = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchAnchorPicker<int>(
              config: PickerConfig<int>(
                loadItems: (_) async => [4],
                idOf: (i) => i,
                labelOf: (i) => 'Item $i',
                searchTermsOf: (i) => ['Item $i'],
              ),
              initialSelectedIds: const [1, 2, 3],
              triggerBuilder: (_, open, __) =>
                  ElevatedButton(onPressed: open, child: const Text('Open')),
              onFinish: ({required added, required removed}) async {
                removedIds = removed;
              },
              onFinishReplaceAll: (ids) async {
                finalIds = ids;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(finalIds.toSet(), {1, 2, 3});
      expect(removedIds, isEmpty);
    },
  );

  testWidgets(
    'client-side reload missing selected ids does not auto-remove them',
    (tester) async {
      final refreshN = ValueNotifier<int>(0);
      var items = [1];
      List<int> finalIds = [];
      List<int> removedIds = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchAnchorPicker<int>(
              config: PickerConfig<int>(
                loadItems: (_) async => items,
                idOf: (i) => i,
                labelOf: (i) => 'Item $i',
                searchTermsOf: (i) => ['Item $i'],
                listenable: refreshN,
              ),
              initialSelectedIds: const [1, 2],
              triggerBuilder: (_, open, __) =>
                  ElevatedButton(onPressed: open, child: const Text('Open')),
              onFinish: ({required added, required removed}) async {
                removedIds = removed;
              },
              onFinishReplaceAll: (ids) async {
                finalIds = ids;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      items = [3];
      refreshN.value++;
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(finalIds.toSet(), {1, 2});
      expect(removedIds, isEmpty);
    },
  );

  testWidgets(
    'parent changing initialSelectedIds while open explicitly reseeds pending',
    (tester) async {
      final selectedN = ValueNotifier<List<int>>(const [1, 2, 3]);
      List<int> finalIds = [];
      List<int> removedIds = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<List<int>>(
              valueListenable: selectedN,
              builder: (context, selectedIds, _) {
                return SearchAnchorPicker<int>(
                  config: PickerConfig<int>(
                    loadItems: (_) async => [1, 2, 3],
                    idOf: (i) => i,
                    labelOf: (i) => 'Item $i',
                    searchTermsOf: (i) => ['Item $i'],
                  ),
                  initialSelectedIds: selectedIds,
                  triggerBuilder: (_, open, __) => ElevatedButton(
                    onPressed: open,
                    child: const Text('Open'),
                  ),
                  onFinish: ({required added, required removed}) async {
                    removedIds = removed;
                  },
                  onFinishReplaceAll: (ids) async {
                    finalIds = ids;
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      selectedN.value = const [1];
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(finalIds, [1]);
      expect(removedIds, isEmpty);
    },
  );

  testWidgets(
    'temporary empty initialSelectedIds while open does not report removals',
    (tester) async {
      final selectedN = ValueNotifier<List<int>>(const [1, 2, 3]);
      var replaceAllCalled = false;
      List<int> removedIds = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<List<int>>(
              valueListenable: selectedN,
              builder: (context, selectedIds, _) {
                return SearchAnchorPicker<int>(
                  config: PickerConfig<int>(
                    loadItems: (_) async => [1, 2, 3],
                    idOf: (i) => i,
                    labelOf: (i) => 'Item $i',
                    searchTermsOf: (i) => ['Item $i'],
                  ),
                  initialSelectedIds: selectedIds,
                  triggerBuilder: (_, open, __) => ElevatedButton(
                    onPressed: open,
                    child: const Text('Open'),
                  ),
                  onFinish: ({required added, required removed}) async {
                    removedIds = removed;
                  },
                  onFinishReplaceAll: (_) async {
                    replaceAllCalled = true;
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      selectedN.value = const [];
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(replaceAllCalled, isFalse);
      expect(removedIds, isEmpty);
    },
  );

  testWidgets('PickerActions changes final ids but do not report removed ids', (
    tester,
  ) async {
    List<int> finalIds = [];
    List<int> removedIds = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchAnchorPicker<int>(
            config: PickerConfig<int>(
              loadItems: (_) async => [1, 2, 3],
              idOf: (i) => i,
              labelOf: (i) => 'Item $i',
              searchTermsOf: (i) => ['Item $i'],
            ),
            initialSelectedIds: const [1, 2, 3],
            headerBuilder: (context, actions, _) {
              return [
                TextButton(
                  onPressed: actions.selectNone,
                  child: const Text('Clear from header'),
                ),
              ];
            },
            triggerBuilder: (_, open, __) =>
                ElevatedButton(onPressed: open, child: const Text('Open')),
            onFinish: ({required added, required removed}) async {
              removedIds = removed;
            },
            onFinishReplaceAll: (ids) async {
              finalIds = ids;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear from header'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save empty'));
    await tester.pumpAndSettle();

    expect(finalIds, isEmpty);
    expect(removedIds, isEmpty);
  });

  testWidgets('selectNone preserves selected ids outside current loaded list', (
    tester,
  ) async {
    List<int> finalIds = [];
    List<int> removedIds = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchAnchorPicker<int>(
            config: PickerConfig<int>(
              loadItems: (_) async => [2, 4],
              idOf: (i) => i,
              labelOf: (i) => 'Item $i',
              searchTermsOf: (i) => ['Item $i'],
            ),
            initialSelectedIds: const [1, 2, 3],
            headerBuilder: (context, actions, _) {
              return [
                TextButton(
                  onPressed: actions.selectNone,
                  child: const Text('Clear current list'),
                ),
              ];
            },
            triggerBuilder: (_, open, __) =>
                ElevatedButton(onPressed: open, child: const Text('Open')),
            onFinish: ({required added, required removed}) async {
              removedIds = removed;
            },
            onFinishReplaceAll: (ids) async {
              finalIds = ids;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear current list'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(finalIds.toSet(), {1, 3});
    expect(removedIds, isEmpty);
  });

  testWidgets('clearLoaded changes final ids without reporting removed ids', (
    tester,
  ) async {
    List<int> finalIds = [];
    List<int> removedIds = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchAnchorPicker<int>(
            config: PickerConfig<int>(
              loadItems: (_) async => [2, 4],
              idOf: (i) => i,
              labelOf: (i) => 'Item $i',
              searchTermsOf: (i) => ['Item $i'],
            ),
            initialSelectedIds: const [1, 2, 3],
            headerBuilder: (context, actions, _) {
              return [
                TextButton(
                  onPressed: actions.clearLoaded,
                  child: const Text('Clear loaded'),
                ),
              ];
            },
            triggerBuilder: (_, open, __) =>
                ElevatedButton(onPressed: open, child: const Text('Open')),
            onFinish: ({required added, required removed}) async {
              removedIds = removed;
            },
            onFinishReplaceAll: (ids) async {
              finalIds = ids;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear loaded'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(finalIds.toSet(), {1, 3});
    expect(removedIds, isEmpty);
  });

  testWidgets('clearLoadedAsDelta reports loaded selected ids as removed', (
    tester,
  ) async {
    List<int> finalIds = [];
    List<int> removedIds = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchAnchorPicker<int>(
            config: PickerConfig<int>(
              loadItems: (_) async => [2, 4],
              idOf: (i) => i,
              labelOf: (i) => 'Item $i',
              searchTermsOf: (i) => ['Item $i'],
            ),
            initialSelectedIds: const [1, 2, 3],
            headerBuilder: (context, actions, _) {
              return [
                TextButton(
                  onPressed: actions.clearLoadedAsDelta,
                  child: const Text('Clear loaded delta'),
                ),
              ];
            },
            triggerBuilder: (_, open, __) =>
                ElevatedButton(onPressed: open, child: const Text('Open')),
            onFinish: ({required added, required removed}) async {
              removedIds = removed;
            },
            onFinishReplaceAll: (ids) async {
              finalIds = ids;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear loaded delta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(finalIds.toSet(), {1, 3});
    expect(removedIds, [2]);
  });

  testWidgets('selectLoadedAsDelta reports loaded unselected ids as added', (
    tester,
  ) async {
    List<int> finalIds = [];
    List<int> addedIds = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchAnchorPicker<int>(
            config: PickerConfig<int>(
              loadItems: (_) async => [2, 4],
              idOf: (i) => i,
              labelOf: (i) => 'Item $i',
              searchTermsOf: (i) => ['Item $i'],
            ),
            initialSelectedIds: const [1, 2, 3],
            headerBuilder: (context, actions, _) {
              return [
                TextButton(
                  onPressed: actions.selectLoadedAsDelta,
                  child: const Text('Select loaded delta'),
                ),
              ];
            },
            triggerBuilder: (_, open, __) =>
                ElevatedButton(onPressed: open, child: const Text('Open')),
            onFinish: ({required added, required removed}) async {
              addedIds = added;
            },
            onFinishReplaceAll: (ids) async {
              finalIds = ids;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select loaded delta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(finalIds.toSet(), {1, 2, 3, 4});
    expect(addedIds, [4]);
  });

  testWidgets('clearFilteredAsDelta reports only filtered selected ids', (
    tester,
  ) async {
    List<int> finalIds = [];
    List<int> removedIds = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchAnchorPicker<int>(
            config: PickerConfig<int>(
              loadItems: (_) async => [1, 2, 3],
              idOf: (i) => i,
              labelOf: (i) => 'Item $i',
              searchTermsOf: (i) => ['Item $i'],
            ),
            initialSelectedIds: const [1, 2, 3],
            headerBuilder: (context, actions, _) {
              return [
                TextButton(
                  onPressed: actions.clearFilteredAsDelta,
                  child: const Text('Clear filtered delta'),
                ),
              ];
            },
            triggerBuilder: (_, open, __) =>
                ElevatedButton(onPressed: open, child: const Text('Open')),
            onFinish: ({required added, required removed}) async {
              removedIds = removed;
            },
            onFinishReplaceAll: (ids) async {
              finalIds = ids;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'Item 2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear filtered delta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(finalIds.toSet(), {1, 3});
    expect(removedIds, [2]);
  });

  testWidgets('selectFilteredAsDelta reports only filtered unselected ids', (
    tester,
  ) async {
    List<int> finalIds = [];
    List<int> addedIds = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchAnchorPicker<int>(
            config: PickerConfig<int>(
              loadItems: (_) async => [1, 2, 3],
              idOf: (i) => i,
              labelOf: (i) => 'Item $i',
              searchTermsOf: (i) => ['Item $i'],
            ),
            initialSelectedIds: const [1],
            headerBuilder: (context, actions, _) {
              return [
                TextButton(
                  onPressed: actions.selectFilteredAsDelta,
                  child: const Text('Select filtered delta'),
                ),
              ];
            },
            triggerBuilder: (_, open, __) =>
                ElevatedButton(onPressed: open, child: const Text('Open')),
            onFinish: ({required added, required removed}) async {
              addedIds = added;
            },
            onFinishReplaceAll: (ids) async {
              finalIds = ids;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'Item 3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select filtered delta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(finalIds.toSet(), {1, 3});
    expect(addedIds, [3]);
  });

  testWidgets('toggleIdAsDelta reports delta while toggleId does not', (
    tester,
  ) async {
    List<int> finalIds = [];
    List<int> addedIds = [];
    List<int> removedIds = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchAnchorPicker<int>(
            config: PickerConfig<int>(
              loadItems: (_) async => [1, 2, 3],
              idOf: (i) => i,
              labelOf: (i) => 'Item $i',
              searchTermsOf: (i) => ['Item $i'],
            ),
            initialSelectedIds: const [1],
            headerBuilder: (context, actions, _) {
              return [
                TextButton(
                  onPressed: () => actions.toggleId(2, true),
                  child: const Text('Toggle pending'),
                ),
                TextButton(
                  onPressed: () => actions.toggleIdAsDelta(3, true),
                  child: const Text('Toggle add delta'),
                ),
                TextButton(
                  onPressed: () => actions.toggleIdAsDelta(1, false),
                  child: const Text('Toggle remove delta'),
                ),
              ];
            },
            triggerBuilder: (_, open, __) =>
                ElevatedButton(onPressed: open, child: const Text('Open')),
            onFinish: ({required added, required removed}) async {
              addedIds = added;
              removedIds = removed;
            },
            onFinishReplaceAll: (ids) async {
              finalIds = ids;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toggle pending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toggle add delta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toggle remove delta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(finalIds.toSet(), {2, 3});
    expect(addedIds, [3]);
    expect(removedIds, [1]);
  });

  testWidgets('empty replace-all can be disabled explicitly', (tester) async {
    var replaceAllCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchAnchorPicker<int>(
            config: PickerConfig<int>(
              loadItems: (_) async => [1],
              idOf: (i) => i,
              labelOf: (i) => 'Item $i',
              searchTermsOf: (i) => ['Item $i'],
            ),
            initialSelectedIds: const [1],
            showSaveEmptyButton: false,
            triggerBuilder: (_, open, __) =>
                ElevatedButton(onPressed: open, child: const Text('Open')),
            onFinishReplaceAll: (_) async {
              replaceAllCalled = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Item 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Save empty'), findsNothing);
    expect(replaceAllCalled, isFalse);
  });
}
