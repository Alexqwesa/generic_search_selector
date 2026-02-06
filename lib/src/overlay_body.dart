import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:generic_search_selector/src/overflow_tooltip_text.dart';
import 'package:generic_search_selector/src/picker_config.dart';

class OverlayBody<T> extends StatefulWidget {
  const OverlayBody({
    super.key,
    required this.header,
    required this.items,
    required this.stableOrder,
    required this.ctrl,
    required this.pendingN,
    required this.mode,
    required this.config,
    required this.onToggleGate,
    required this.close,
    this.itemBuilder,
  });

  final List<Widget> header;
  final List<T> items;
  final List<T> stableOrder;

  final SearchController ctrl;
  final ValueNotifier<Set<int>> pendingN;

  final PickerMode mode;
  final PickerConfig<T> config;

  final Future<bool> Function(T item, bool nextSelected)? onToggleGate;
  final void Function([String? reason, bool skipCloseView]) close;
  final Widget Function(
    BuildContext context,
    T item,
    bool isSelected,
    ValueChanged<bool?> onToggle,
  )?
  itemBuilder;

  @override
  State<OverlayBody<T>> createState() => _OverlayBodyState<T>();
}

class _OverlayBodyState<T> extends State<OverlayBody<T>> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          widget.close(null, true);
        }
      },
      child: ListenableBuilder(
        listenable: widget.ctrl,
        builder: (context, _) {
          final q = widget.ctrl.text.trim().toLowerCase();

          bool matches(T it) {
            if (q.isEmpty) return true;
            for (final s in widget.config.searchTermsOf(it)) {
              if (s.toLowerCase().contains(q)) return true;
            }
            return false;
          }

          final filtered = widget.stableOrder.where(matches).toList();
          final total = widget.header.length + filtered.length;

          return Column(
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
                    child: ValueListenableBuilder<Set<int>>(
                      valueListenable: widget.pendingN,
                      builder: (context, pendingSnapshot, __) {
                        return ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: total,
                          itemBuilder: (context, index) {
                            if (index < widget.header.length)
                              return widget.header[index];

                            final item = filtered[index - widget.header.length];
                            final id = widget.config.idOf(item);
                            final checked = pendingSnapshot.contains(id);

                            final icon =
                                widget.config.iconOf?.call(item) ??
                                const Icon(Icons.person);
                            final label = widget.config.labelOf(item);
                            final tip = widget.config.tooltipOf?.call(item);

                            final labelWidget = (tip == null)
                                ? OverflowTooltipText(label)
                                : Tooltip(
                                    message: tip,
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );

                            Future<void> toggle(bool next) async {
                              if (widget.onToggleGate != null) {
                                final ok = await widget.onToggleGate!(
                                  item,
                                  next,
                                );
                                if (!ok) return;
                              }

                              // Re-read latest after awaits.
                              final current = widget.pendingN.value;

                              if (widget.mode == PickerMode.radio ||
                                  widget.mode == PickerMode.radioToggle) {
                                // radioToggle: if next is false (unselecting), we allow it -> empty set.
                                // radio: we do NOT allow unselecting (must pick something).
                                if (!next && widget.mode == PickerMode.radio) {
                                  // Re-selecting same item in normal radio mode -> no-op/change nothing
                                  return;
                                }

                                widget.pendingN.value = next ? {id} : {};
                                widget.close('radio');
                                return;
                              }

                              // Unselect logic with behaviors
                              if (!next &&
                                  (widget.config.isItemInUse?.call(item) ??
                                      false)) {
                                switch (widget.config.unselectBehavior) {
                                  case UnselectBehavior.block:
                                    return;
                                  case UnselectBehavior.showWarning:
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Item is currently in use.',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  case UnselectBehavior.alert:
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Remove item?'),
                                        content: Text(
                                          '${widget.config.labelOf(item)} is currently in use. Removing it might affect other data.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    break;
                                  case UnselectBehavior.allow:
                                    break;
                                }
                              }

                              final s = {...current};
                              next ? s.add(id) : s.remove(id);
                              widget.pendingN.value = s;
                            }

                            if (widget.itemBuilder != null) {
                              return widget.itemBuilder!(
                                context,
                                item,
                                checked,
                                (v) => toggle(v ?? false),
                              );
                            }

                            return CheckboxListTile(
                              checkboxShape:
                                  (widget.mode == PickerMode.radio ||
                                      widget.mode == PickerMode.radioToggle)
                                  ? const CircleBorder()
                                  : null,
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
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
