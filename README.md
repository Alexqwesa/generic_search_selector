# Generic Search Selector

A small Flutter library that turns Material 3 `SearchAnchor` into a reusable
picker widget with selection state, optional nested “sub-pickers”, and a clean
configuration surface.

It is designed for cases where you need:

- A searchable list picker (multi or radio selection)
- “Selected first” ordering and stable ordering
- Custom header content (actions, nested pickers, filters, etc.)
- A simple API that hides overlay / lifecycle gotchas

Online demo:
- Example app (web): <ADD_YOUR_ONLINE_DEMO_LINK_HERE>

Technical deep dive:
- See `docs/TECHNICAL_OVERVIEW.md` for architecture, lifecycle edge cases,
  and why some fixes exist (dynamic keys, PostFrameCallback, etc.).


## Features

- `SearchAnchorPicker<T>`: drop-in picker built on Flutter Material 3
- Two selection modes:
  - `PickerMode.multi` (checkbox style)
  - `PickerMode.radio` (single select)
- Fully generic item type `T` via `PickerConfig<T>`
- Header builder with `PickerActions` for advanced scenarios:
  - Clear selection
  - Sync selection with external state
  - Nested sub-pickers (optional)
- Works with any state management approach:
  - `setState`
  - `ValueNotifier`
  - Riverpod, Provider, BLoC, etc.


## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  generic_search_selector:  # soon
  
dependencies:
  generic_search_selector:
    git:
      url: https://github.com/Alexqwesa/generic_search_selector.git
      ref: main
```

## Quick example

Minimal multi-select with local state.
(Works the same with Riverpod/Bloc/etc — just update your state in onToggle.)

Use `triggerBuilder` for opening the picker so the trigger can react to picker version changes.

```dart
import 'package:flutter/material.dart';
import 'package:generic_search_selector/picker_config.dart';
import 'package:generic_search_selector/search_anchor_picker.dart';

class Person {
  Person(this.id, this.name);
  final int id;
  final String name;
}

class PeoplePickerDemo extends StatefulWidget {
  const PeoplePickerDemo({super.key});

  @override
  State<PeoplePickerDemo> createState() => _PeoplePickerDemoState();
}

class _PeoplePickerDemoState extends State<PeoplePickerDemo> {
  final _items = <Person>[
    Person(1, 'Alice'),
    Person(2, 'Bob'),
    Person(3, 'Charlie'),
  ];

  final _selectedIds = <int>{};

  late final PickerConfig<Person> _config = PickerConfig<Person>(
    title: 'Pick people',
    loadItems: (_) async => _items,
    idOf: (p) => p.id,
    labelOf: (p) => p.name,
    searchTermsOf: (p) => [p.name, p.id.toString()],
    selectedFirst: true,
  );

  @override
  Widget build(BuildContext context) {
    return SearchAnchorPicker<Person>(
      config: _config,
      mode: PickerMode.multi,
      initialSelectedIds: _selectedIds.toList()..sort(),
      onToggle: (item, next) async {
        setState(() {
          next ? _selectedIds.add(item.id) : _selectedIds.remove(item.id);
        });
        return true;
      },
      triggerBuilder: (_, open, __) => IconButton(
        tooltip: 'Open picker',
        onPressed: open,
        icon: const Icon(Icons.person_search),
      ),
      maxHeight: 420,
      minWidth: 320,
    );
  }
}
```

## Nested Pickers

You can use your own `SearchAnchorPicker` for nested pickers, or use the `SubPickerTile` helper in `headerBuilder` to create them easily (e.g., for filtering or adding items from another source).

It handles synchronization with the parent picker:
*   **Removals**: If items are removed in the sub-picker, they are automatically removed from the parent's pending selection.
*   **Additions**: Added items are **NOT** automatically selected in the parent (defaulting to "unselected"), giving you control.
*   **Popup positioning**: Use `menuOffset` to shift the nested popup relative to its trigger, and `menuOffsetAnimationDuration` to control how quickly that offset animates in.
*   **Scalability**: Closed pickers do not keep a permanent trigger `GlobalKey`; popup-only keys are created on demand and cleared when the popup closes.

```dart
SubPickerTile<MyItem>(
  title: 'Add from Sub-list',
  config: subConfig,
  parentActions: actions, // Pass parent actions to automate removal cleanup
  initialSelectedIds: currentSubIds,
  menuOffset: const Offset(40, 12), // from trigger position
  menuOffsetAnimationDuration: const Duration(milliseconds: 120),
  onFinish: (ids, {required added, required removed}) async {
      // 1. Update your data model (e.g. repository)
      await myRepo.add(added);
      await myRepo.remove(removed);
      
      // 2. Pending selection cleanup (removals) is handled automatically!
  }
)
```

## TODO: 
headerBuilder: (context, actions) => allUnitsHeader(context, actions, allJsas, ref),
footerBuilder: 
customActions?
- enum PopupThemes{glass , classic}
- don't use external listen - it only needed while popup is open, use additional list as listenable provided by picker (if needed to update listenable.value=[...old])
- editItem callback 
- in agent_readme maybe add comments // ui state updated by library, but you need to persist the changes 
- check MediaQuery.of(context).size - if there is enogh space - use some offset for sublist popup (slightly below trigger)  
- is window size very small  - use fullscreen popups   like my   SmartAlertDialog(fullscreenBreakpoint: 600, ...
- UX problem: users didn't understand that there is search field in popup - add some hint or icon
- make it more like material 3 SearchAnchor - pass through parameters to SearchAnchor
- allow more small customizations - like icon, trailingIcons of items in list without full itemBuilder
- allow: selectedStyle (bold default)? better selectedWidget?
 

## MIT License
