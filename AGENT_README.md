# Generic Search Selector: Agent Guide

This repository implements a versatile, highly configurable **Search Anchor Picker** for Flutter. It supports single/multi selection, sub-pickers, async operations, and robust state management.

## 1. Core API Components

### `SearchAnchorPicker<T>`
The main widget that opens a search view (Overlay).
- **Generic `<T>`**: The type of items being picked (e.g., `DemoItem`, `User`).
- **`config`**: `PickerConfig<T>` (Required) - Defines behavior, data loading, and callbacks.
- **`mode`**: `PickerMode` - `multi` (default), `radio`, or `radioToggle`.
- **`initialSelectedIds`**: `List<int>` - Seeds the initial selection state.
- **`onToggle`**: `Future<bool> Function(T item, bool next)` - Intercepts selection events. Return `true` to allow change.
- **`headerBuilder`**: Defines custom widgets (like sub-pickers) at the top of the list.
- **`triggerBuilder`**: Defines the widget (button/icon) that opens the picker.

### `PickerConfig<T>`
Configuration object for the picker.
- **`loadItems`**: `Future<List<T>> Function(BuildContext)` - Loads the list of selectable items.
- **`idOf`**: `int Function(T)` - Unique ID for each item.
- **`labelOf`**: `String Function(T)` - Display label.
- **`listenable`**: `Listenable?` - Triggers a reload of `loadItems` when notified (e.g., `ValueNotifier`).
- **`autoRemoveDanglingSelections`**: `bool` (Default `false`).
    - If `true`, the picker automatically cleans up selected IDs that are no longer present in the loaded universe.
    - **Use Case**: When a sub-picker removes items from the parent's data source, this flag ensures the parent picker unchecks them immediately. (Added in `main_radio.dart` refactor).
- **`isItemInUse`**: Predicate to warn users before unselecting items used elsewhere.

---

## 2. Modes

- **`PickerMode.multi`**: Standard checkboxes. Multiple items can be selected.
- **`PickerMode.radio`**: Radio buttons. Only one item selected. Clicking a selected item generally does nothing.
- **`PickerMode.radioToggle`**: Like radio, but clicking the *selected* item again deselects it (toggle off).

---

## 3. Common Patterns & Examples

### Basic Setup
```dart
SearchAnchorPicker<MyItem>(
  config: PickerConfig<MyItem>(
    title: 'Select Users',
    loadItems: (_) async => myApi.getUsers(),
    idOf: (item) => item.id,
    labelOf: (item) => item.name,
    searchTermsOf: (item) => [item.name, item.email],
  ),
  onChanged: (ids) => print('Selected: $ids'),
  triggerBuilder: (context, open, _) => 
      IconButton(icon: Icon(Icons.add), onPressed: open),
)
```

### Sub-Pickers (Nested Selection)
Use `SubPickerTile` inside `headerBuilder` to allow modifying the list *from within* the picker.

```dart
headerBuilder: (ctx, actions, allItems) {
  return [
    SubPickerTile<MyItem>(
      parentActions: actions, // Pass parent actions to sync state
      title: 'Add External Users',
      // ... config for sub-picker ...
      onFinish: (ids, {required added, required removed}) async {
        // 1. Update your actual data source
        await myRepo.addItems(added);
        await myRepo.removeItems(removed);
        
        // 2. Notify parent to reload (via listenable or setState)
        _refreshNotifier.value++; 
      },
    ),
    const Divider(),
  ];
}
```

### Unified Radio Selection (Transient Items)
For radio pickers where you can *also* pick from a sub-list (which then "moves" that item to the main list):

1. **State**: Maintain `_mainItems` and `_extraItems` (transient).
2. **Load**: `loadItems` returns `[..._mainItems, ..._extraItems]`.
3. **Logic**:
   - If user picks from **Sub-Picker**: Add to `_extraItems`, clear `_mainItems` selection.
   - If user picks from **Main List**: Clear `_extraItems`.
4. **Config**: Set `autoRemoveDanglingSelections: true` so that when `_extraItems` is cleared, the picker UI updates immediately.

```dart
// main_radio.dart pattern
onToggle: (item, next) async {
  if (next) {
    if (isMainItem(item)) {
       // Selected a standard item -> Clear transient extras
       _extraItems.clear();
       _refreshNotifier.value++; // Trigger reload
    }
  }
  return true;
}
```


---

## 4. Advanced Scenarios

### Validation / Selection Limits
Use `onToggle` to enforce business logic, such as a maximum number of selectable items.

```dart
onToggle: (item, next) async {
  if (next) {
    // Check current selection count (you need to track this state externally or via actions if exposed)
    if (mySelectedIds.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max 3 items allowed')),
      );
      return false; // Prevent selection
    }
  }
  return true; // Allow selection
},
```

### Custom Trigger UI (Chips)
Instead of a simple icon, you can display the actual selected items as chips that open the picker when tapped.

```dart
triggerBuilder: (context, open, _) {
  if (mySelectedIds.isEmpty) {
    return ActionChip(label: const Text('Select items...'), onPressed: open);
  }
  return Wrap(
    spacing: 8,
    children: [
      ...mySelectedIds.map((id) => InputChip(
            label: Text('#$id'),
            onDeleted: () => removeId(id), // Handle external removal
          )),
      IconButton(icon: const Icon(Icons.add), onPressed: open),
    ],
  );
},
```

## 5. Tips for Agents

- **Async & State**: Always use `PickerConfig.listenable` if your data changes externally (e.g., via sub-pickers). The picker won't reload automatically otherwise.
- **Keys**: unique keys are crucial for `SubPickerTile` to ensure they don't lose state during parent rebuilds. Use `actions.getKey('unique_id')`.
- **Layout**: The library separates the "Anchor" (trigger) from the "Display" (chips). You usually want to build a custom `Column` or `Wrap` to show selected chips *outside* the picker, using `triggerBuilder` just for the open button.
- **Performance**: The picker uses `ListView.builder` but filters locally. For massive datasets (>10k), consider implementing server-side search (though `loadItems` currently expects a full list return).
- **Ghost Selections**: Use `autoRemoveDanglingSelections` to prevent "ghost" selections (count > 0 but no checks visible) when items are removed from the data source while selected.
