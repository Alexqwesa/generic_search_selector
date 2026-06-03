# Agent guide — generic_search_selector

Rules for agents (and humans) working on this library or integrating it. Consumer apps that depend on the git package should also keep a short **Cursor skill** (e.g. `.cursor/skills/generic-search-selector/SKILL.md`) with triggers and pitfalls — not a copy of this file.

## Two patterns that look alike

| Pattern | Checkbox updates | When to persist |
|--------|------------------|-----------------|
| **`SubPickerTile`** (nested sublist) | Immediately via internal `_pendingN` | **`onFinish`** when the sub-popup closes (save-on-close) |
| **`onToggle` on `SearchAnchorPicker`** | Only after **`onToggle` returns `true`** | Inside **`onToggle`** (sync or async — you choose) |

- **Sublist membership** (pool / “add from DB”, intersection with parent list): prefer **`SubPickerTile` + `onFinish`**.
- **Record assignment on the main list**: use **`onToggle`** (or **`onFinish`** / **`onFinishReplaceAll`** on the root picker if you only persist on close).
- **Async server save in a sublist** without save-on-close: either use **`SubPickerTile` + `onFinish`**, or use **`onToggle`** with **`onToggleMode: OnToggleMode.optimistic`** (or `return true` immediately and persist in the background — see README “Async onToggle”).

The quick README example uses **`onToggle` + sync `setState`**. Nested examples use **`SubPickerTile`**. It is easy to put **`onToggle` + slow `await`** on a sublist and wonder why checkboxes freeze until the future completes.

## UI vs persistence

```dart
// UI selection while the overlay is open is owned by the library (_pendingN).
// You must persist to your repo / API yourself (onToggle, onFinish, or both).
```

- **`actions.refresh()`** reloads items from **`loadItems`**; it does **not** replace **`listenable`** for external pool/catalog changes — wire **`PickerConfig.listenable`** when the item source can change while the popup is open.
- **`idOf`** must be **stable across reloads**. If directory rows use `entity:type:id` and pool rows use `pool:id`, **`idOf`**, **`initialSelectedIds`**, and server payloads must share **one key space** or checkboxes and reloads disagree even when the API is used correctly.

## `initialSelectedIds` — when external seed syncs

There is an intentional split between **class-level comments** and **runtime behavior**:

| Widget state | `initialSelectedIds` changes from parent |
|------------|----------------------------------------|
| Popup **closed** | Next open seeds from the new list (via `didUpdateWidget` → `_pendingN`). |
| Popup **open** | **`didUpdateWidget` still syncs `_pendingN`** from `initialSelectedIds` (post-frame). This supports **sub-picker membership** updates while the parent overlay stays open (e.g. parent `headerBuilder` rebuilds with a new intersection). |

**Implication:** Do not assume “open overlay ignores external `initialSelectedIds`.” For a main picker where the user is mid-edit, drive selection through **`actions.pending`** / **`onToggle`**, not by thrashing **`initialSelectedIds`** on every rebuild.

**`SubPickerTile`:** Pass **`initialSelectedIds`** as the current intersection (e.g. pool IDs ∩ directory IDs). Removals in the sub-picker sync to **`parentActions`** on **`onFinish`**; additions are **not** auto-selected in the parent (by design).

## `SubPickerTile` — save-on-close (default)

- Checkboxes update in-overlay immediately.
- **`onFinish(added:, removed:)`** runs once when the sub-popup closes.
- With **`parentActions`**: **`removed`** IDs are stripped from parent pending; **`added`** IDs are **not** auto-added to parent pending.

**Save on every click** is **not** the default `SubPickerTile` flow. Options:

1. Stay on **`SubPickerTile`** and accept save-on-close (library-intended for sublists).
2. Use a nested **`SearchAnchorPicker`** with **`onToggle`** + **`OnToggleMode.optimistic`** (or immediate `return true` + background persist).
3. Custom **`itemBuilder`** that calls your API — you own ordering vs library gates.

## `onToggle` gate and async work

Default (**`OnToggleMode.awaitGate`**): the overlay **awaits** **`onToggle`** before toggling **`_pendingN`**. Slow `await` blocks the checkbox.

**`OnToggleMode.optimistic`**: checkbox updates first; **`onToggle`** runs in the background. If it returns **`false`**, the library **reverts** that toggle.

```dart
SearchAnchorPicker<Item>(
  onToggleMode: OnToggleMode.optimistic,
  onToggle: (item, next) async {
    try {
      await api.setMembership(item.id, next);
      return true;
    } catch (_) {
      return false; // reverts checkbox
    }
  },
);
```

For **validation** (max count, permissions), use **`awaitGate`** and return **`false`** to reject.

## Client-side vs server-side `loadItems`

`loadItems` is display/search data, not deletion truth.

- Missing IDs are preserved whether `loadItems` returns a full client-side list or a server-side page.
- Explicit user row checks/unchecks still update `_pendingN`; `onFinish(added:, removed:)` reports those IDs.
- Header code may change final pending IDs with `actions.setPending(...)`, `toggleId(...)`, `pendingClearLoaded()`, `pendingClearFiltered()`, `pendingSelectLoaded()`, or `pendingSelectFiltered()`, but those changes are only reflected in `onFinishReplaceAll(finalIds)`, not `added` / `removed`.
- Header code may intentionally emit deltas with `toggleIdAsDelta(...)`, `clearLoadedAsDelta()`, `clearFilteredAsDelta()`, `selectLoadedAsDelta()`, or `selectFilteredAsDelta()`.
- Parent `initialSelectedIds` changes may reseed final IDs, but they are not reported as `added` / `removed`; do not call add/delete APIs from seed diffs.
- `actions.pendingClearLoaded()` removes only IDs from the current loaded result, not hidden server-side selections.
- Bulk helpers do not run row-level `unselectBehavior`; header code owns any bulk confirmation/warning UX.
- Empty `onFinishReplaceAll` saves require the user to press the save-empty button. `showSaveEmptyButton: false` disables empty replace-all saves.
- If the backend knows an ID was deleted, update parent state / `initialSelectedIds` explicitly after that deletion source succeeds.

## `PickerActions` (header / sub-pickers)

- **`pending` / `setPending` / `toggleId`**: in-overlay only.
- **`refresh()`**: reload **`loadItems`** (post-framed).
- **`getKey(id)`**: stable **`GlobalKey`** for the **active** popup only — cleared on close; do not cache across sessions.
- Safe to call from build (post-framed).

## Radio modes

**`PickerMode.radio` / `radioToggle`**: selection still goes through the same gate; picker may close on select. Prefer **`onFinish`** or sync **`onToggle`** for persistence.

## Debugging checklist

1. Sublist bug → **`SubPickerTile` + `onFinish`** vs **`onToggle`** on the wrong widget?
2. Frozen checkbox → async **`onToggle`** without **`optimistic`** / immediate **`true`**?
3. Wrong checked state after reload → **`idOf`** / **`initialSelectedIds`** key mismatch?
4. Server-side search drops selections → code is probably overwriting **`initialSelectedIds`** or pending state externally.
5. List stale → **`listenable`** missing; **`refresh()`** alone won’t fix external notifiers.
6. Parent/sub disagree → **`parentActions`** + **`onFinish`** vs manual pending?

## Files to read first

- `lib/src/search_anchor_picker.dart` — overlay lifecycle, `_pendingN`, `initialSelectedIds` sync
- `lib/src/sub_picker_tile.dart` — nested picker, parent sync
- `lib/src/overlay_body.dart` — checkbox toggle + `onToggle` gate
- `lib/src/picker_config.dart` — config, `OnToggleMode`, actions
- `test/sub_picker_test.dart` — sub-picker contracts

## Consumer repo skill (not in this package)

Apps that depend on git `ref:` should add:

```
.cursor/skills/generic-search-selector/SKILL.md
```

Short: when to use **`SubPickerTile`**, **`idOf`** key space, async pitfall, link to this file.
