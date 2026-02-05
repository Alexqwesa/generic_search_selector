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
  PickerConfig({
    required this.loadItems,
    required this.idOf,
    required this.labelOf,
    required this.searchTermsOf,
    this.tooltipOf,
    this.iconOf,
    this.comparator,
    this.title,
    this.selectedFirst = true,
    this.listenable,
    this.unselectBehavior = UnselectBehavior.allow,
    this.isItemInUse,
  });

  /// internal callback to open the picker. (Set by SearchAnchorPicker).
  /// Do not set this manually.
  VoidCallback? internalOnOpen;

  /// Internal callback to close the picker. (Set by SearchAnchorPicker).
  /// Do not set this manually.
  void Function([String? reason])? internalOnClose;

  /// Programmatically open the picker.
  ///
  /// Requires the [PickerConfig] to be currently attached to a [SearchAnchorPicker] (or [SubPickerTile]).
  void open() {
    if (internalOnOpen != null) {
      internalOnOpen!();
    }
  }

  /// Programmatically close the picker.
  ///
  /// Requires the [PickerConfig] to be currently attached to a [SearchAnchorPicker] (or [SubPickerTile]).
  void close([String? reason]) {
    if (internalOnClose != null) {
      internalOnClose!(reason);
    }
  }

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

  /// If provided, the overlay will rebuild when this notifies.
  /// Use this when your items source is a ChangeNotifier / ValueNotifier / etc.
  final Listenable? listenable;

  /// Strategy to handle deselection of items that might be "in use".
  final UnselectBehavior unselectBehavior;

  /// Predicate to check if an item is currently "in use" externally.
  /// If true, [unselectBehavior] will be triggered on deselection.
  final bool Function(T)? isItemInUse;

  PickerConfig<T> copyWith({
    LoadItems<T>? loadItems,
    int Function(T)? idOf,
    String Function(T)? labelOf,
    Iterable<String> Function(T)? searchTermsOf,
    String Function(T)? tooltipOf,
    Widget Function(T)? iconOf,
    int Function(T a, T b)? comparator,
    String? title,
    bool? selectedFirst,
    Listenable? listenable,
    UnselectBehavior? unselectBehavior,
    bool Function(T)? isItemInUse,
  }) {
    return PickerConfig<T>(
      loadItems: loadItems ?? this.loadItems,
      idOf: idOf ?? this.idOf,
      labelOf: labelOf ?? this.labelOf,
      searchTermsOf: searchTermsOf ?? this.searchTermsOf,
      tooltipOf: tooltipOf ?? this.tooltipOf,
      iconOf: iconOf ?? this.iconOf,
      comparator: comparator ?? this.comparator,
      title: title ?? this.title,
      selectedFirst: selectedFirst ?? this.selectedFirst,
      listenable: listenable ?? this.listenable,
      unselectBehavior: unselectBehavior ?? this.unselectBehavior,
      isItemInUse: isItemInUse ?? this.isItemInUse,
    );
  }
}

typedef OnFinish =
    Future<void> Function(
      List<int> finalIds, {
      required List<int> added,
      required List<int> removed,
    });

enum PickerMode { multi, radio }

enum UnselectBehavior {
  block,
  showWarning,
  alert,
  allow,
  // keepSelected,
}

/// Actions exposed to headerBuilder so callers never need InheritedWidget lookups.
///
/// This is intentionally thin:
/// - It operates on the in-overlay pending selection only.
/// - It never calls setState; it only updates [pendingN] and closes the picker.
class PickerActions<T> {
  PickerActions({
    required this.pendingN,
    required this.idOf,
    required this.close,
    required this.mode,
    required this.getKey,
    required this.refresh,
  });

  final ValueNotifier<Set<int>> pendingN;
  final int Function(T) idOf;
  final void Function([String? reason]) close;
  final GlobalKey Function(Object id) getKey;
  final VoidCallback refresh;
  final PickerMode mode;

  Set<int> get pending => pendingN.value;

  void setPending(Set<int> ids) => pendingN.value = ids;

  void selectAll(Iterable<int> ids) => setPending(ids.toSet());

  void selectNone() => setPending(<int>{});

  void toggleId(int id, bool next) {
    final s = {...pending};
    next ? s.add(id) : s.remove(id);
    setPending(s);
  }
}

enum CloseQueryBehavior { keep, clear }
