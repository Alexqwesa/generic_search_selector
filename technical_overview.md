# Technical Overview: Generic Search Selector

This document provides a technical deep-dive into the `SearchAnchorPicker` library, explaining the architectural decisions, edge case handling, and the rationale behind specific fixes such as dynamic key management, post-frame scheduling, and popup positioning.

## General Architecture

The library began as a wrapper around Flutter's `SearchAnchor`, but nested pickers eventually needed more control than the stock search-view route could provide. The public API still looks like a search-anchor-based picker, while the popup itself is now rendered with a custom overlay.

* **`SearchAnchorPicker<T>`**: The main entry point. It manages high-level configuration, opens the popup, and handles selection lifecycle.
* **`PickerActions<T>`**: A controller object passed to the header builder. It exposes methods to modify selection state (`pendingN`), allowing sub-pickers or custom buttons to interact with the main picker.
* **`OverlayBody<T>`**: The widget displayed inside the popup surface. It renders the list of items and any custom header content.
* **State Management**: Instead of depending only on `setState`, the library uses `ValueNotifier`s (`pendingN`, `viewTickN`) to update selection and list content without rebuilding everything unnecessarily.

## Edge Cases And Technical Decisions

### 1. Custom overlay instead of raw `SearchAnchor` route
**Why it's needed:**
Nested sub-pickers exposed two limitations of the stock `SearchAnchor` route:

* It clamps popup geometry to the route bounds, which made child menus look clipped when they needed to extend past the parent popup's right edge.
* Its internal popup positioning was difficult to control for submenu offsets and produced transform-related issues in nested overlay scenarios.

**Current approach:**

* The picker inserts an `OverlayEntry` into the current route overlay.
* Popup coordinates are measured from the trigger widget when the popup opens.
* The popup is placed with normal `Positioned` layout, not `CompositedTransformFollower`.
* This allows submenu popups to extend outside the parent popup's visual bounds when desired.

### 2. `PopScope`
**Why it's still needed:**
Even with a custom popup, back-navigation semantics still matter.

* **Role**: `PopScope` in `OverlayBody` allows the picker to react correctly when the user navigates back.
* **Logic**: It ensures cleanup logic still runs before the picker finalizes its result and closes.

### 3. Dynamic key management
**Why keys are still needed in a few places:**
When the popup opens, `OverlayBody` is mounted in a separate overlay subtree.

* **The issue**: If the popup rebuilds, Flutter can lose track of the identity of internal widgets, especially nested sub-pickers.
* **Symptoms**: A sub-picker can lose state or close unexpectedly when the parent popup rebuilds.
* **Current solution**: The trigger itself no longer uses a permanent `GlobalKey`; popup geometry is measured from the trigger `BuildContext` only when opening.
* **Automated manager**: Stable `GlobalKey`s are still available through `getKey(id)` for popup/header widgets that need preserved identity across rebuilds.
* **Lifecycle**: Those managed keys are created only on demand while the popup is active and are cleared when the popup closes, which keeps closed pickers lightweight even when many instances exist on a page.

### 4. `addPostFrameCallback`
**Why it's needed:**
You often see this pattern:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  _pendingN.value = ...;
});
```

* **The constraint**: In Flutter, you cannot trigger rebuild-causing state changes while a widget is still building.
* **The scenario**: A sub-picker closes and returns a result to the parent, and the parent wants to update immediately.
* **The crash**: If that update happens synchronously during build, Flutter throws a "setState() called during build" error.
* **The fix**: `postFrameCallback` defers the update until after the current frame is complete.

### 5. `menuOffset` for nested popups
**Why it exists:**
Submenus often need slightly different coordinates than the trigger tile's exact position.

* **API**: `GenericSearchAnchorPicker` and `GenericSubPickerTile` expose `menuOffset` and `menuOffsetAnimationDuration`.
* **Behavior**: The popup opens at the measured trigger position and quickly animates to the requested offset.
* **Use case**: This is mainly for nested menus that should open to the side or slightly below the trigger.

### 6. Search header styling
The popup header uses a real Material `SearchBar` rather than a plain `TextField`.

* **Why**: It more closely matches Flutter's built-in search UI and keeps the search field behavior familiar.
* **Localization**: Back, clear, and search hint strings are taken from `MaterialLocalizations` when possible.

## Conclusion

The library now solves the major boilerplate problems of searchable nested pickers without relying on the stock `SearchAnchor` route for popup layout:

1. **State persistence**: It keeps selected items stable even when the popup closes.
2. **Nesting**: It supports sub-pickers whose popups can extend beyond parent popup bounds.
3. **Cleaner code**: `PickerConfig` and related abstractions keep data loading separate from UI behavior.

The internal complexity is still real, but that is exactly why the library is valuable: it hides overlay lifecycle, geometry, and key-management details behind a much simpler consumer-facing API.
