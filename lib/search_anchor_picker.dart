import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:generic_search_selector/picker_config.dart';

import 'default_tooltip.dart';

/// Scope available only inside picker overlay (header + list tiles).
class PickerScope<T> extends InheritedWidget {
  const PickerScope({
    super.key,
    required super.child,
    required this.pending,
    required this.setPending,
    required this.toggleId,
    required this.close,
    required this.openSubmenu,
    required this.config,
    required this.allItems,
    required this.mode,
  });

  final Set<int> pending;
  final void Function(Set<int> ids) setPending;

  final void Function(int id, bool next) toggleId;

  final void Function([String? reason]) close;

  /// Open a submenu picker (closes current view first).
  final Future<void> Function(
    PickerConfig<dynamic> config, {
    required Iterable<int> seedIds,
    required PickerMode mode,
    OnFinish? onFinish,
  })
  openSubmenu;

  final PickerConfig<T> config;
  final List<T> allItems;
  final PickerMode mode;

  static PickerScope<T> of<T>(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PickerScope<T>>();
    assert(scope != null, 'PickerScope<$T> not found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(PickerScope<T> oldWidget) {
    // pending changes should rebuild header widgets if they read it
    return pending != oldWidget.pending || allItems != oldWidget.allItems;
  }
}

/// Generic SearchAnchor-based picker (multi-select / radio) with stable
/// in-overlay state and optional header actions via InheritedWidget scope.
class SearchAnchorPicker<T> extends StatefulWidget {
  const SearchAnchorPicker({
    super.key,
    required this.config,
    required this.initialSelectedIds,
    this.mode = PickerMode.multi,
    this.onFinish,
    this.onToggle, // optional, used for remote update gate
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
  });

  final PickerConfig<T> config;

  final List<int> initialSelectedIds;

  final PickerMode mode;

  /// Called once on close (diff vs open snapshot).
  final OnFinish? onFinish;

  /// Optional gating for toggles (remote ops).
  ///
  /// Return false to reject the UI change.
  final Future<bool> Function(T item, bool nextSelected)? onToggle;

  final SearchController? searchController;

  /// If provided, used to build trigger (gets open() and version tick).
  final Widget Function(BuildContext context, VoidCallback open, int version)? triggerBuilder;

  final Widget? triggerChild;

  final Widget iconWhenEmpty;
  final Widget iconWhenSelected;
  final double? iconSize;

  final double maxHeight;
  final double minWidth;

  /// Header content (preferred). Has access to PickerScope<T>.
  final List<Widget> Function(BuildContext context)? headerBuilder;

  /// Legacy static header tiles (if headerBuilder is null).
  final List<Widget>? headerTiles;

  /// Overrides config.selectedFirst if not null.
  final bool? selectedFirst;

  @override
  State<SearchAnchorPicker<T>> createState() => _SearchAnchorPickerState<T>();
}

class _SearchAnchorPickerState<T> extends State<SearchAnchorPicker<T>> {
  late final SearchController _ownedController = SearchController();

  SearchController get _ctrl => widget.searchController ?? _ownedController;

  int _refreshTick = 0;

  // Locked while overlay open:
  Set<int> _pending = <int>{};
  Set<int> _openedSnapshot = <int>{};

  // Stable order computed once per open / items refresh:
  List<T> _stableOrder = const [];

  bool _isOpen = false;

  @override
  void dispose() {
    if (widget.searchController == null) {
      _ownedController.dispose();
    }
    super.dispose();
  }

  void _open() {
    _openedSnapshot = widget.initialSelectedIds.toSet();
    _pending = {..._openedSnapshot};
    _stableOrder = const [];
    _isOpen = true;
    _ctrl.openView();
  }

  void _close([String? reason]) {
    _ctrl.closeView(reason);

    final before = _openedSnapshot;
    final after = _pending;

    final added = after.difference(before).toList();
    final removed = before.difference(after).toList();

    // Finish after frame to avoid "locked tree" type issues.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _isOpen = false;

      if (widget.onFinish != null) {
        await widget.onFinish!(after.toList(), added: added, removed: removed);
      }

      if (!mounted) return;
      setState(() => _refreshTick++);
    });
  }

  void _setPending(Set<int> ids) {
    setState(() => _pending = ids);
  }

  void _toggleId(int id, bool next) {
    final s = {..._pending};
    next ? s.add(id) : s.remove(id);
    _setPending(s);
  }

  Future<void> _openSubmenu(
    PickerConfig<dynamic> config, {
    required Iterable<int> seedIds,
    required PickerMode mode,
    OnFinish? onFinish,
  }) async {
    // Close current overlay first, then open submenu.
    _ctrl.closeView('submenu');

    await Future<void>.delayed(Duration.zero);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SearchAnchorPicker<dynamic>(
              config: config,
              initialSelectedIds: seedIds.toList(),
              mode: mode,
              onFinish: onFinish,
              maxHeight: widget.maxHeight,
              minWidth: widget.minWidth,
              // In dialog, we use a simple close trigger
              triggerBuilder: (c, open, v) => Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: open,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(config.title ?? 'Open'),
                ),
              ),
            ),
          ),
        );
      },
    );

    // Reopen original overlay if you want; usually you don't.
    // If you do, you can call _ctrl.openView() here.
  }

  Future<List<T>> _loadItems() => widget.config.loadItems(context);

  bool _matches(T it, String qLower) {
    if (qLower.isEmpty) return true;
    for (final s in widget.config.searchTermsOf(it)) {
      if (s.toLowerCase().contains(qLower)) return true;
    }
    return false;
  }

  void _computeStableOrder(List<T> items) {
    final selectedFirst = widget.selectedFirst ?? widget.config.selectedFirst;

    if (!selectedFirst) {
      final copy = [...items];
      if (widget.config.comparator != null) copy.sort(widget.config.comparator);
      _stableOrder = copy;
      return;
    }

    final selectedAtOpen = _openedSnapshot;

    final selected = <T>[];
    final others = <T>[];

    for (final it in items) {
      (selectedAtOpen.contains(widget.config.idOf(it)) ? selected : others).add(it);
    }

    if (widget.config.comparator != null) {
      selected.sort(widget.config.comparator);
      others.sort(widget.config.comparator);
    }

    _stableOrder = [...selected, ...others];
  }

  @override
  Widget build(BuildContext context) {
    // Important: if initialSelectedIds changes while popup is open, ignore it.
    if (!_isOpen) {
      _pending = widget.initialSelectedIds.toSet();
    }

    final hasSelection = widget.initialSelectedIds.isNotEmpty;

    return SearchAnchor(
      searchController: _ctrl,
      isFullScreen: false,
      viewConstraints: BoxConstraints(maxHeight: widget.maxHeight, minWidth: widget.minWidth),
      suggestionsBuilder: (_, __) => const <Widget>[],
      builder: (context, controller) {
        if (widget.triggerBuilder != null) {
          return widget.triggerBuilder!(context, _open, _refreshTick);
        }

        if (widget.triggerChild != null) {
          return GestureDetector(onTap: _open, child: widget.triggerChild);
        }

        return IconButton(
          iconSize: widget.iconSize,
          icon: hasSelection ? widget.iconWhenSelected : widget.iconWhenEmpty,
          tooltip: widget.config.title,
          onPressed: _open,
        );
      },
      viewBuilder: (suggestions) {
        return FutureBuilder<List<T>>(
          future: _loadItems(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final items = snap.data!;
            if (_stableOrder.isEmpty) {
              _computeStableOrder(items);
            }

            final q = _ctrl.text.trim().toLowerCase();
            final base = _stableOrder.isEmpty ? items : _stableOrder;
            final filtered = base.where((it) => _matches(it, q)).toList();

            final header = widget.headerBuilder != null
                ? widget.headerBuilder!(context)
                : (widget.headerTiles ?? const <Widget>[]);

            return PickerScope<T>(
              pending: _pending,
              setPending: _setPending,
              toggleId: _toggleId,
              close: _close,
              openSubmenu: _openSubmenu,
              config: widget.config,
              allItems: items,
              mode: widget.mode,
              child: _PickerOverlayBody<T>(
                header: header,
                filtered: filtered,
                ctrl: _ctrl,
                pending: _pending,
                mode: widget.mode,
                config: widget.config,
                onToggleGate: widget.onToggle,
                onLocalToggle: (id, next) async {
                  _toggleId(id, next);
                  if (widget.mode == PickerMode.radio) {
                    _close('radio');
                  }
                },
              ),
            );
          },
        );
      },
      viewOnClose: () {
        // SearchAnchor calls this when overlay closes. We handle finish ourselves
        // via _close() so we do nothing here.
      },
    );
  }
}

class _PickerOverlayBody<T> extends StatefulWidget {
  const _PickerOverlayBody({
    required this.header,
    required this.filtered,
    required this.ctrl,
    required this.pending,
    required this.mode,
    required this.config,
    required this.onToggleGate,
    required this.onLocalToggle,
  });

  final List<Widget> header;
  final List<T> filtered;
  final SearchController ctrl;
  final Set<int> pending;
  final PickerMode mode;
  final PickerConfig<T> config;

  final Future<bool> Function(T item, bool nextSelected)? onToggleGate;
  final Future<void> Function(int id, bool next) onLocalToggle;

  @override
  State<_PickerOverlayBody<T>> createState() => _PickerOverlayBodyState<T>();
}

class _PickerOverlayBodyState<T> extends State<_PickerOverlayBody<T>> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.header.length + widget.filtered.length;

    return ConstrainedBox(
      constraints: const BoxConstraints(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: const {
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.touch,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                interactive: true,
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: total,
                  itemBuilder: (context, index) {
                    if (index < widget.header.length) {
                      return widget.header[index];
                    }

                    final item = widget.filtered[index - widget.header.length];
                    final id = widget.config.idOf(item);
                    final checked = widget.pending.contains(id);

                    final icon = widget.config.iconOf?.call(item) ?? const Icon(Icons.circle);
                    final tooltip = widget.config.tooltipOf?.call(item);

                    Future<void> toggle(bool next) async {
                      if (widget.onToggleGate != null) {
                        final ok = await widget.onToggleGate!(item, next);
                        if (!ok) return;
                      }
                      await widget.onLocalToggle(id, next);
                    }

                    final label = widget.config.labelOf(item);
                    final customTooltip = widget.config.tooltipOf?.call(item);

                    final labelWidget = (customTooltip == null)
                        ? OverflowTooltipText(label) // tooltip only if overflow
                        : Tooltip(
                            message: customTooltip,
                            child: Text(label, overflow: TextOverflow.ellipsis),
                          );

                    return CheckboxListTile(
                      checkboxShape: widget.mode == PickerMode.radio ? const CircleBorder() : null,
                      value: checked,
                      onChanged: (v) => toggle(v ?? false),
                      title: Row(
                        children: [
                          icon,
                          const SizedBox(width: 6),
                          Expanded(child: labelWidget),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
