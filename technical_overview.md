# Technical Overview: Generic Search Selector

This document provides a technical deep-dive into the `SearchAnchorPicker` library, explaining the architectural decisions, edge case handling, and the rationale behind specific fixes (Keys, PostFrameCallback, etc.).

## General Architecture

The library extends Flutter's `SearchAnchor` to create a reusable, state-aware picker widget.

*   **`SearchAnchorPicker<T>`**: The main entry point. It wraps `SearchAnchor` and manages high-level configuration (items repo, selection mode, styling).
*   **`PickerActions<T>`**: A controller object passed to the header builder. It exposes methods to modify selection state (`pendingN`), allowing sub-pickers or custom buttons to interact with the main picker.
*   **`OverlayBody<T>`**: The widget displayed inside the `SearchAnchor`'s view overlay. It renders the list of items (`ListView`) and the header.
*   **State Management**: Instead of depending on simple `setState`, the library uses `ValueNotifier`s (`pendingN`, `viewTickN`) to granularly update parts of the UI (like the selection count or the list content) without rebuilding the entire overlay unnecessarily.

## Edge Cases & technical Decisions

### 1. `CanPop` and `PopScope`
**Why it's needed:**
The `SearchAnchor` overlay functions like a route on the navigator stack. When the user taps "Back" or clicks outside, the system attempts to "pop" this route.
*   **Role**: We use `PopScope` in `OverlayBody` to intercept this pop event.
*   **Logic**: It allows us to trigger cleanup logic (like resetting search text) or saving state before the view actually closes.
*   **Crash Prevention**: It ensures that we don't try to access the `SearchController` *after* the route has already technically closed but the widget is still in the tree during the exit animation.

### 2. The `GlobalKey` (and `KeyManager`)
**Why keys are crucial:**
When the `SearchAnchor` view opens, it mounts the `OverlayBody` into a separate part of the widget tree (the Overlay).
*   **The Issue**: If the overlay rebuilds (e.g., due to a `setState` in `SearchAnchorPicker`), Flutter might lose track of the identity of internal widgets, especially expensive ones like nested `SearchAnchorPicker`s (Sub-pickers).
*   **Symptoms**: Without keys, opening a sub-picker and then triggering a rebuild in the parent could cause the sub-picker to lose its state or close unexpectedly.
*   **Solution**: `GlobalKey`s ensure that a specific widget in the code corresponds to the exact same Element in the framework's render tree, even if parents rebuild.
*   **Automated Manager**: We implemented `getKey(id)` to automatically assign and manage these keys, so the user doesn't have to manually create `final key = GlobalKey()` for every item.

### 3. `addPostFrameCallback`
**Why it's needed:**
You often see this pattern:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  _pendingN.value = ...;
});
```
*   **The Constraint**: In Flutter, you cannot call `setState` (or notify listeners that trigger a build) *while* a widget is currently building.
*   **The Scenario**: A sub-picker might close and return a result to the parent. The parent receives this result in `onFinish` or `didUpdateWidget` and wants to update its UI immediately.
*   **The Crash**: If this update happens synchronously during the build phase of the parent, Flutter throws "setState() called during build".
*   **The Fix**: `postFrameCallback` schedules the update to happen *after* the current frame takes shape, satisfying Flutter's lifecycle rules.

## Conclusion

**This library is a good extension for `SearchAnchor`**


It successfully solves the major boilerplate problems of using raw `SearchAnchor`s:
1.  **State Persistence**: It handles the complex dance of keeping selected items in memory even when the overlay is closed.
2.  **Nesting**: It provides a robust architecture for "Sub-pickers" (nested searches), which is notoriously difficult to get right with raw Flutter widgets due to the disposal lifecycle issues we fixed.
3.  **Cleaner Code**: The `ItemsRepo` and `PickerConfig` abstractions separate *data fetching* from *UI rendering*, following clean architecture principles.

**Caveat**: The internal complexity (lifecycle management, keys) is high, but that is exactly why this library is valuable—it encapsulates that complexity so the consumer code (`main.dart`) remains simple.
