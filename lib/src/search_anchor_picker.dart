import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:generic_search_selector/src/picker_debug.dart';
import 'package:generic_search_selector/src/overlay_body.dart';
import 'package:generic_search_selector/src/picker_config.dart';

/// Generic SearchAnchor-based picker with stable in-overlay selection.
///
/// Key properties:
/// - **No GlobalKey**
/// - In-overlay selection stored in [_pendingN] (ValueNotifier)
/// - External seed ([initialSelectedIds]) is synced only when popup is not open
/// - Close is always deferred (post-frame) to avoid overlay/build-scope assertions
/// - Optional [PickerConfig.listenable] allows live updates (e.g. ChangeNotifier repo)
class GenericSearchAnchorPicker<T, K> extends StatefulWidget {
  const GenericSearchAnchorPicker({
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
    this.itemBuilder,
    this.menuOffset = Offset.zero,
    this.menuOffsetAnimationDuration = const Duration(milliseconds: 120),
  });

  final GenericPickerConfig<T, K> config;

  /// External seed selection.
  /// While overlay is open, changes here will NOT clobber pending selection.
  final List<K> initialSelectedIds;

  final PickerMode mode;

  /// Optional gate (e.g. remote ops). Return false to reject UI change.
  final Future<bool> Function(T item, bool nextSelected)? onToggle;

  /// Called once when overlay closes (diff vs open snapshot).
  final GenericOnFinish<K>? onFinish;

  final SearchController? searchController;

  /// Optional trigger builder (gets open callback + version tick).
  final Widget Function(BuildContext context, VoidCallback open, int version)?
  triggerBuilder;

  final Widget? triggerChild;

  final Widget iconWhenEmpty;
  final Widget iconWhenSelected;
  final double? iconSize;

  final double maxHeight;
  final double minWidth;

  /// Preferred: build header widgets with [PickerActions].
  final List<Widget> Function(
    BuildContext context,
    GenericPickerActions<T, K> actions,
    List<T> allItems,
  )?
  headerBuilder;

  /// Legacy static header tiles (used if headerBuilder is null).
  final List<Widget>? headerTiles;

  /// Overrides config.selectedFirst if set.
  final bool? selectedFirst;

  final CloseQueryBehavior closeQueryBehavior;

  /// Optional builder for custom item rendering in the list.
  final Widget Function(
    BuildContext context,
    T item,
    bool isSelected,
    VoidCallback toggle,
  )?
  itemBuilder;

  /// Offset applied to the popup menu after it opens.
  ///
  /// The menu is shown at its default position and then quickly animates to
  /// this translation, which is useful for nested menus that need slightly
  /// different coordinates.
  final Offset menuOffset;

  final Duration menuOffsetAnimationDuration;

  @override
  State<GenericSearchAnchorPicker<T, K>> createState() =>
      _GenericSearchAnchorPickerState<T, K>();
}

class SearchAnchorPicker<T> extends GenericSearchAnchorPicker<T, int> {
  const SearchAnchorPicker({
    super.key,
    required super.config,
    required super.initialSelectedIds,
    super.mode,
    super.onToggle,
    super.onFinish,
    super.searchController,
    super.triggerBuilder,
    super.triggerChild,
    super.iconWhenEmpty,
    super.iconWhenSelected,
    super.iconSize,
    super.maxHeight,
    super.minWidth,
    super.headerBuilder,
    super.headerTiles,
    super.selectedFirst,
    super.closeQueryBehavior,
    super.itemBuilder,
    super.menuOffset,
    super.menuOffsetAnimationDuration,
  });
}

class _GenericSearchAnchorPickerState<T, K>
    extends State<GenericSearchAnchorPicker<T, K>> {
  late final SearchController _owned = SearchController();
  OverlayEntry? _overlayEntry;
  OverlayState? _overlayState;
  Rect _openedAnchorRect = Rect.zero;
  Size _openedAnchorSize = Size.zero;
  BuildContext? _triggerContext;

  SearchController get _ctrl => widget.searchController ?? _owned;

  late final ValueNotifier<Set<K>> _pendingN = ValueNotifier<Set<K>>(
    widget.initialSelectedIds.toSet(),
  );

  Set<K> _openedSnapshot = <K>{};
  bool _open = false;

  int _tick = 0;
  final ValueNotifier<int> _viewTickN = ValueNotifier(0);

  /// Stable order is derived from items at open time.
  /// While open, we keep the *relative* order stable but allow new items to appear.
  List<K> _stableIds = <K>[];

  VoidCallback? _listenableCb;

  @override
  void initState() {
    super.initState();
    _attachListenable(widget.config.listenable);
    _bindConfigControl();
  }

  void _bindConfigControl() {
    widget.config.internalOnOpen = _requestOpen;
    // Usage of closure protects against tearing off methods if signatures vary slightly,
    // and allows cleaner unbinding.
    widget.config.internalOnClose = ([reason]) => _close(reason);
  }

  void _unbindConfigControl(GenericPickerConfig<T, K> config) {
    if (config.internalOnOpen == _requestOpen) config.internalOnOpen = null;
    // We can't identify the closure wrapper easily so we blindly clear it
    // assuming we are the owner.
    config.internalOnClose = null;
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

      // Auto-cleanup dangling selections if configured
      if (widget.config.autoRemoveDanglingSelections) {
        final currentPending = _pendingN.value;
        if (currentPending.isNotEmpty) {
          final validIds = items.map(widget.config.idOf).toSet();
          final newPending = currentPending.intersection(validIds);
          if (newPending.length != currentPending.length) {
            _pendingN.value = newPending;
          }
        }
      }

      _itemsSnapshot = items;
      // _loading = false;
      _viewTickN.value++;
    });
  }

  @override
  void didUpdateWidget(covariant GenericSearchAnchorPicker<T, K> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.config != widget.config) {
      _unbindConfigControl(oldWidget.config);
      _bindConfigControl();
    }

    if (oldWidget.config.listenable != widget.config.listenable) {
      _detachListenable(oldWidget.config.listenable);
      _attachListenable(widget.config.listenable);
    }

    // Sync from external seed.
    // We allow this even if open, to support use cases like "Sub Picker" updating valid selection.
    if (!_listEquals(oldWidget.initialSelectedIds, widget.initialSelectedIds)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pendingN.value = widget.initialSelectedIds.toSet();
      });
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _unbindConfigControl(widget.config);
    _detachListenable(widget.config.listenable);
    _pendingN.dispose();
    if (widget.searchController == null) {
      _owned.dispose();
    }
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

    _stableIds = <K>[];
    _open = true;

    // Load items on open
    _reload();
  }

  void _requestOpen() {
    PickerDebug.log('SearchAnchorPicker: Opening picker');
    if (_open) return;
    _onOpen();
    _showOverlay();
  }

  void _close([String? reasonIgnored, bool skipCloseView = false]) {
    PickerDebug.log(
      'SearchAnchorPicker: Closing picker. Reason=$reasonIgnored, skipCloseView=$skipCloseView',
    );
    final queryAtClose = _ctrl.text;

    _removeOverlay();

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

      // Guard against multiple calls to _close triggering multiple onFinish callbacks
      if (!_open) return;
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

  void _showOverlay() {
    final overlay = Overlay.of(context);
    if (overlay == null) return;
    _overlayState = overlay;
    _openedAnchorSize = _anchorSize();
    _openedAnchorRect = _currentAnchorRect();
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(builder: (context) => _buildOverlayEntry());
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _overlayState = null;
  }

  Size _anchorSize() {
    final anchorContext = _triggerContext;
    if (anchorContext == null) {
      return Size(widget.minWidth, 0);
    }
    final renderBox = anchorContext.findRenderObject() as RenderBox?;
    return renderBox?.size ?? Size(widget.minWidth, 0);
  }

  Rect _currentAnchorRect() {
    final anchorContext = _triggerContext;
    if (anchorContext == null) {
      return Offset.zero & Size(widget.minWidth, 0);
    }

    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    final overlayBox = _overlayState?.context.findRenderObject() as RenderBox?;

    if (anchorBox == null || overlayBox == null) {
      return Offset.zero & Size(widget.minWidth, 0);
    }

    final offset = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    return offset & anchorBox.size;
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
      (_openedSnapshot.contains(widget.config.idOf(it)) ? selected : others)
          .add(it);
    }

    if (widget.config.comparator != null) {
      selected.sort(widget.config.comparator);
      others.sort(widget.config.comparator);
    }

    _stableIds = [
      ...selected.map(widget.config.idOf),
      ...others.map(widget.config.idOf),
    ];
  }

  /// Keep existing order for known ids; append new ids; drop removed ids.
  void _syncStableIds(List<T> items) {
    final idsNow = items.map(widget.config.idOf).toSet();

    // Drop ids that no longer exist.
    _stableIds = _stableIds.where(idsNow.contains).toList();

    // Append new ids.
    final known = _stableIds.toSet();
    final newItems = items
        .where((it) => !known.contains(widget.config.idOf(it)))
        .toList();

    if (newItems.isNotEmpty) {
      if (widget.config.comparator != null)
        newItems.sort(widget.config.comparator);
      _stableIds.addAll(newItems.map(widget.config.idOf));
    }

    // If stableIds is empty (first build), compute from scratch.
    if (_stableIds.isEmpty) _computeStableIds(items);
  }

  Widget _buildOverlayView() {
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

        final actions = GenericPickerActions<T, K>(
          pendingN: _pendingN,
          idOf: widget.config.idOf,
          close: _close,
          mode: widget.mode,
          getKey: _getKey,
          refresh: _reload,
        );

        final header = widget.headerBuilder != null
            ? widget.headerBuilder!(context, actions, items)
            : (widget.headerTiles ?? const <Widget>[]);

        final byId = <K, T>{for (final it in items) widget.config.idOf(it): it};
        final stableOrder = <T>[
          for (final id in _stableIds)
            if (byId.containsKey(id)) byId[id]!,
        ];

        return OverlayBody<T, K>(
          header: header,
          items: items,
          stableOrder: stableOrder.isEmpty ? items : stableOrder,
          ctrl: _ctrl,
          pendingN: _pendingN,
          mode: widget.mode,
          config: widget.config,
          onToggleGate: widget.onToggle,
          close: _close,
          itemBuilder: widget.itemBuilder,
        );
      },
    );
  }

  Widget _buildSearchField() {
    return Builder(
      builder: (context) {
        final l10n = MaterialLocalizations.of(context);

        return ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) {
            return SearchBar(
              controller: _ctrl,
              autoFocus: true,
              hintText: widget.config.title ?? l10n.searchFieldLabel,
              leading: IconButton(
                tooltip: l10n.backButtonTooltip,
                icon: const Icon(Icons.arrow_back),
                onPressed: _close,
              ),
              trailing: _ctrl.text.isEmpty
                  ? null
                  : [
                      IconButton(
                        tooltip: l10n.clearButtonTooltip,
                        icon: const Icon(Icons.close),
                        onPressed: () => _ctrl.clear(),
                      ),
                    ],
              elevation: const WidgetStatePropertyAll<double>(0),
              backgroundColor: const WidgetStatePropertyAll<Color>(
                Colors.transparent,
              ),
              overlayColor: const WidgetStatePropertyAll<Color>(
                Colors.transparent,
              ),
              side: const WidgetStatePropertyAll<BorderSide>(
                BorderSide(color: Colors.transparent),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPopupSurface(double maxHeight) {
    final width = math.max(widget.minWidth, _openedAnchorSize.width);

    return Material(
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: width,
          maxWidth: width,
          maxHeight: maxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchField(),
            const Divider(height: 1),
            Flexible(child: _buildOverlayView()),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayEntry() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = constraints.biggest;
        final anchorRect = _openedAnchorRect;
        final popupHeight = math.min(widget.maxHeight, screenSize.height);

        double dx = widget.menuOffset.dx;
        double dy = widget.menuOffset.dy;

        final bottom = anchorRect.top + dy + popupHeight;
        if (bottom > screenSize.height) {
          dy -= bottom - screenSize.height;
        }

        final top = anchorRect.top + dy;
        if (top < 0) {
          dy -= top;
        }

        final availableHeight = math.max(
          140.0,
          screenSize.height - math.max(anchorRect.top + dy, 0),
        );
        final resolvedMaxHeight = math.min(widget.maxHeight, availableHeight);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !(ModalRoute.of(context)?.isCurrent ?? true),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _close,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            TweenAnimationBuilder<Offset>(
              tween: Tween<Offset>(begin: Offset.zero, end: Offset(dx, dy)),
              duration: widget.menuOffsetAnimationDuration,
              builder: (context, offset, _) {
                return Positioned(
                  left: anchorRect.left + offset.dx,
                  top: anchorRect.top + offset.dy,
                  child: _buildPopupSurface(resolvedMaxHeight),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.initialSelectedIds.isNotEmpty;
    final trigger = widget.triggerBuilder != null
        ? widget.triggerBuilder!(context, _requestOpen, _tick)
        : widget.triggerChild != null
        ? GestureDetector(onTap: _requestOpen, child: widget.triggerChild)
        : IconButton(
            iconSize: widget.iconSize,
            tooltip: widget.config.title,
            icon: hasSelection ? widget.iconWhenSelected : widget.iconWhenEmpty,
            onPressed: _requestOpen,
          );

    return Builder(
      builder: (triggerContext) {
        _triggerContext = triggerContext;
        return trigger;
      },
    );
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
