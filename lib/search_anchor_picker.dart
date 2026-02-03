import 'dart:async';

import 'package:flutter/material.dart';
import 'package:generic_search_selector/overlay_body.dart';
import 'package:generic_search_selector/picker_config.dart';

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
  });

  final ValueNotifier<Set<int>> pendingN;
  final int Function(T) idOf;
  final void Function([String? reason]) close;
  final GlobalKey Function(Object id) getKey;
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

/// Generic SearchAnchor-based picker with stable in-overlay selection.
///
/// Key properties:
/// - **No GlobalKey**
/// - In-overlay selection stored in [_pendingN] (ValueNotifier)
/// - External seed ([initialSelectedIds]) is synced only when popup is not open
/// - Close is always deferred (post-frame) to avoid overlay/build-scope assertions
/// - Optional [PickerConfig.listenable] allows live updates (e.g. ChangeNotifier repo)
class SearchAnchorPicker<T> extends StatefulWidget {
  const SearchAnchorPicker({
    super.key,
    required this.config,
    required this.initialSelectedIds,
    this.mode = PickerMode.multi,
    this.onToggle,
    this.onFinish,
    this.searchController,
    this.triggerBuilder,
    this.triggerChild,
    this.iconWhenEmpty = const Icon(Icons.search),
    this.iconWhenSelected = const Icon(Icons.search, color: Colors.green),
    this.iconSize,
    this.maxHeight = 520,
    this.minWidth = 400,
    this.headerBuilder,
    this.headerTiles,
    this.selectedFirst,
    this.closeQueryBehavior = CloseQueryBehavior.keep,
  });

  final PickerConfig<T> config;

  /// External seed selection.
  /// While overlay is open, changes here will NOT clobber pending selection.
  final List<int> initialSelectedIds;

  final PickerMode mode;

  /// Optional gate (e.g. remote ops). Return false to reject UI change.
  final Future<bool> Function(T item, bool nextSelected)? onToggle;

  /// Called once when overlay closes (diff vs open snapshot).
  final OnFinish? onFinish;

  final SearchController? searchController;

  /// Optional trigger builder (gets open callback + version tick).
  final Widget Function(BuildContext context, VoidCallback open, int version)? triggerBuilder;

  final Widget? triggerChild;

  final Widget iconWhenEmpty;
  final Widget iconWhenSelected;
  final double? iconSize;

  final double maxHeight;
  final double minWidth;

  /// Preferred: build header widgets with [PickerActions].
  final List<Widget> Function(BuildContext context, PickerActions<T> actions, List<T> allItems)?
  headerBuilder;

  /// Legacy static header tiles (used if headerBuilder is null).
  final List<Widget>? headerTiles;

  /// Overrides config.selectedFirst if set.
  final bool? selectedFirst;

  final CloseQueryBehavior closeQueryBehavior;

  @override
  State<SearchAnchorPicker<T>> createState() => _SearchAnchorPickerState<T>();
}

class _SearchAnchorPickerState<T> extends State<SearchAnchorPicker<T>> {
  late final SearchController _owned = SearchController();

  SearchController get _ctrl => widget.searchController ?? _owned;

  late final ValueNotifier<Set<int>> _pendingN = ValueNotifier<Set<int>>(
    widget.initialSelectedIds.toSet(),
  );

  Set<int> _openedSnapshot = <int>{};
  bool _open = false;

  int _tick = 0;
  final ValueNotifier<int> _viewTickN = ValueNotifier(0);

  /// Stable order is derived from items at open time.
  /// While open, we keep the *relative* order stable but allow new items to appear.
  List<int> _stableIds = <int>[];

  VoidCallback? _listenableCb;

  @override
  void initState() {
    super.initState();
    _attachListenable(widget.config.listenable);
  }

  List<T>? _itemsSnapshot;

  // bool _loading = false; // Unused
  final Map<Object, GlobalKey> _headerKeys = {};

  GlobalKey _getKey(Object id) {
    return _headerKeys.putIfAbsent(id, () => GlobalKey());
  }

  void _reload() {
    if (!mounted) return;
    // _loading = true;
    // Notify overlay to show loading if needed (optional)
    widget.config.loadItems(context).then((items) {
      if (!mounted) return;
      _itemsSnapshot = items;
      // _loading = false;
      _viewTickN.value++;
    });
  }

  @override
  void didUpdateWidget(covariant SearchAnchorPicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.config.listenable != widget.config.listenable) {
      _detachListenable(oldWidget.config.listenable);
      _attachListenable(widget.config.listenable);
    }

    // Sync from external seed ONLY when overlay is not open.
    if (!_open && !_listEqualsInt(oldWidget.initialSelectedIds, widget.initialSelectedIds)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pendingN.value = widget.initialSelectedIds.toSet();
      });
    }
  }

  @override
  void dispose() {
    _detachListenable(widget.config.listenable);
    _pendingN.dispose();
    // if (!_open) _viewTickN.dispose();
    // Same fix as controller: avoid disposing if view is animating out.
    // _viewTickN.dispose();
    // if (widget.searchController == null) {
    // Prevent crash if disposed while overlay is animating out
    // if (!_open) _owned.dispose();
    // }
    super.dispose();
  }

  void _attachListenable(Listenable? l) {
    if (l == null) return;
    _listenableCb = () {
      if (!mounted) return;
      // Triggers reload which eventually updates _viewTickN
      _reload();
    };
    l.addListener(_listenableCb!);
  }

  void _detachListenable(Listenable? l) {
    if (l == null || _listenableCb == null) return;
    l.removeListener(_listenableCb!);
    _listenableCb = null;
  }

  void _onOpen() {
    _openedSnapshot = widget.initialSelectedIds.toSet();
    _pendingN.value = {..._openedSnapshot};

    _stableIds = <int>[];
    _open = true;

    // Load items on open
    _reload();
  }

  void _requestOpen() {
    _onOpen();
    _ctrl.openView();
  }

  void _close([String? _reasonIgnored, bool skipCloseView = false]) {
    final queryAtClose = _ctrl.text;

    // IMPORTANT: do not pass reason -> it can affect controller text next open.
    if (!skipCloseView) {
      _ctrl.closeView('');
    }

    // Apply query behavior on next frame (avoid build-scope issues).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.closeQueryBehavior == CloseQueryBehavior.clear) {
        _ctrl.text = '';
      } else {
        _ctrl.text = queryAtClose;
      }
    });

    final before = _openedSnapshot;
    final after = _pendingN.value;

    final added = after.difference(before).toList();
    final removed = before.difference(after).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _open = false;

      // Clear header keys on close to release them
      _headerKeys.clear();

      if (widget.onFinish != null) {
        await widget.onFinish!(after.toList(), added: added, removed: removed);
      }

      if (!mounted) return;
      _viewTickN.value++;
      setState(() => _tick++);
    });
  }

  void _computeStableIds(List<T> items) {
    final selectedFirst = widget.selectedFirst ?? widget.config.selectedFirst;

    final ids = items.map(widget.config.idOf).toList();

    if (!selectedFirst) {
      if (widget.config.comparator != null) {
        final sorted = [...items]..sort(widget.config.comparator);
        _stableIds = sorted.map(widget.config.idOf).toList();
      } else {
        _stableIds = ids;
      }
      return;
    }

    final selected = <T>[];
    final others = <T>[];

    for (final it in items) {
      (_openedSnapshot.contains(widget.config.idOf(it)) ? selected : others).add(it);
    }

    if (widget.config.comparator != null) {
      selected.sort(widget.config.comparator);
      others.sort(widget.config.comparator);
    }

    _stableIds = [...selected.map(widget.config.idOf), ...others.map(widget.config.idOf)];
  }

  /// Keep existing order for known ids; append new ids; drop removed ids.
  void _syncStableIds(List<T> items) {
    final idsNow = items.map(widget.config.idOf).toSet();

    // Drop ids that no longer exist.
    _stableIds = _stableIds.where(idsNow.contains).toList();

    // Append new ids.
    final known = _stableIds.toSet();
    final newItems = items.where((it) => !known.contains(widget.config.idOf(it))).toList();

    if (newItems.isNotEmpty) {
      if (widget.config.comparator != null) newItems.sort(widget.config.comparator);
      _stableIds.addAll(newItems.map(widget.config.idOf));
    }

    // If stableIds is empty (first build), compute from scratch.
    if (_stableIds.isEmpty) _computeStableIds(items);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.initialSelectedIds.isNotEmpty;

    return SearchAnchor(
      searchController: _ctrl,
      isFullScreen: false,
      viewConstraints: BoxConstraints(maxHeight: widget.maxHeight, minWidth: widget.minWidth),
      suggestionsBuilder: (_, __) => const <Widget>[],
      builder: (context, controller) {
        if (widget.triggerBuilder != null) {
          return widget.triggerBuilder!(context, _requestOpen, _tick);
        }

        if (widget.triggerChild != null) {
          return GestureDetector(onTap: _requestOpen, child: widget.triggerChild);
        }

        return IconButton(
          iconSize: widget.iconSize,
          tooltip: widget.config.title,
          icon: hasSelection ? widget.iconWhenSelected : widget.iconWhenEmpty,
          onPressed: _requestOpen,
        );
      },
      viewBuilder: (suggestions) {
        return ValueListenableBuilder<int>(
          valueListenable: _viewTickN,
          builder: (context, tick, _) {
            final items = _itemsSnapshot;
            if (items == null) {
              return const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (_stableIds.isEmpty) {
              _computeStableIds(items);
            } else {
              _syncStableIds(items);
            }

            final actions = PickerActions<T>(
              pendingN: _pendingN,
              idOf: widget.config.idOf,
              close: _close,
              mode: widget.mode,
              getKey: _getKey,
            );

            final header = widget.headerBuilder != null
                ? widget.headerBuilder!(context, actions, items)
                : (widget.headerTiles ?? const <Widget>[]);

            // Resolve stable order into actual items list.
            final byId = <int, T>{for (final it in items) widget.config.idOf(it): it};
            final stableOrder = <T>[
              for (final id in _stableIds)
                if (byId.containsKey(id)) byId[id]!,
            ];

            return OverlayBody<T>(
              header: header,
              items: items,
              stableOrder: stableOrder.isEmpty ? items : stableOrder,
              ctrl: _ctrl,
              pendingN: _pendingN,
              mode: widget.mode,
              config: widget.config,
              onToggleGate: widget.onToggle,
              close: _close,
            );
          },
        );
      },
    );
  }
}

bool _listEqualsInt(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
