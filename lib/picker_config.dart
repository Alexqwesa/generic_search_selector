import 'package:flutter/widgets.dart';

typedef LoadItems<T> = Future<List<T>> Function(BuildContext context);

/// Configuration for a [SearchAnchorPicker].
///
/// This object is intentionally "meta": the picker UI is generic, and you adapt
/// it to a domain model [T] by providing small functions:
/// - how to load items
/// - how to identify an item
/// - how to render / search an item
///
/// The picker keeps a stable “in-overlay” selection while open:
/// changes to [initialSelectedIds] from outside will not clobber the user’s
/// pending selection until the overlay is closed.
class PickerConfig<T> {
  const PickerConfig({
    required this.loadItems,
    required this.idOf,
    required this.labelOf,
    required this.searchTermsOf,
    this.tooltipOf,
    this.iconOf,
    this.comparator,
    this.title,
    this.selectedFirst = true,
  });

  /// Loads the full list of selectable items.
  ///
  /// Called when the picker overlay opens (and may be called again if you choose
  /// to refresh). Keep it fast; cache upstream if needed.
  final LoadItems<T> loadItems;

  /// Returns a stable integer identifier for [T].
  ///
  /// Used for:
  /// - selection state (Set<int>)
  /// - computing added/removed diffs on close
  /// - equality / matching across reloads
  final int Function(T) idOf;

  /// Returns the primary label shown in the list for [T].
  ///
  /// The picker will render this label with ellipsis. If [tooltipOf] is null,
  /// the default behavior is to show a tooltip only when this label overflows.
  final String Function(T) labelOf;

  /// Returns a set of searchable strings for [T].
  ///
  /// The search box filters items by checking if any term contains the
  /// lowercase query substring.
  ///
  /// Tips:
  /// - include localized names
  /// - include email / code fields if users search by them
  final Iterable<String> Function(T) searchTermsOf;

  /// Optional tooltip text for [T].
  ///
  /// - If provided, the picker shows this tooltip (typically always).
  /// - If null, the picker falls back to a default behavior:
  ///   show a tooltip only when the [labelOf] text is ellipsized (overflow).
  final String Function(T)? tooltipOf;

  /// Optional leading icon builder for [T].
  ///
  /// If null, the picker uses a default icon.
  final Widget Function(T)? iconOf;

  /// Optional comparator used to sort items.
  ///
  /// Sorting is applied when computing the stable in-overlay order:
  /// - if [selectedFirst] is true: selected-at-open items are sorted, and the
  ///   remaining items are sorted separately.
  /// - if [selectedFirst] is false: all items are sorted together.
  final int Function(T a, T b)? comparator;

  /// Optional title used for trigger tooltips, etc.
  final String? title;

  /// If true, the overlay list is ordered as:
  /// 1) items selected at popup-open
  /// 2) all remaining items
  ///
  /// This order is computed once per open (stable while the overlay is open).
  final bool selectedFirst;
}

typedef OnFinish =
    Future<void> Function(
      List<int> finalIds, {
      required List<int> added,
      required List<int> removed,
    });

enum PickerMode { multi, radio }
