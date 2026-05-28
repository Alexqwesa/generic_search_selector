# Template: copy into your app repo

Path (example for `dashboard_tree`):

```
.cursor/skills/generic-search-selector/SKILL.md
```

---

```markdown
---
name: generic-search-selector
description: Flutter picker from git generic_search_selector — sublists, async save, idOf keys
---

# generic_search_selector (consumer)

Use when editing pickers built with `SearchAnchorPicker` / `SubPickerTile` from
`generic_search_selector` (git dependency).

## Quick rules

| UI | Use |
|----|-----|
| Pool / sublist membership | `SubPickerTile` + `onFinish` (save-on-close) |
| Main list assign | `onToggle` or root `onFinish` |
| Async save, checkbox must not freeze | `onToggleMode: OnToggleMode.optimistic` or immediate `return true` + background save |
| Server-side search / pagination | Treat `loadItems` as display data only; missing IDs are not removals |

## Pitfalls

- Async `onToggle` without `optimistic` **blocks** checkboxes until the future completes.
- `actions.refresh()` reloads items only — use `PickerConfig.listenable` for external pool/catalog updates.
- `idOf` and `initialSelectedIds` must share **one stable key space** (e.g. don't mix `entity:type:id` with `pool:id`).
- Don't fix sublist bugs with parent `refreshTick` / listenable alone — check sub-picker pattern first.
- `loadItems` is **not deletion truth**. Server-side pages may omit selected IDs; do not infer removal from absence.
- `onFinish(... removed:)` means explicit picker removals only: user unselects or `PickerActions` changes.
- Parent `initialSelectedIds` changes can reseed final `ids`, but must not trigger delete APIs from seed diffs. A temporary empty seed from a failed request should not remove anything remotely.

## Library docs

https://github.com/Alexqwesa/generic_search_selector/blob/main/docs/AGENTS.md
```
