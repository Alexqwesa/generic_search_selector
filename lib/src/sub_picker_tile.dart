import 'package:flutter/material.dart';
import 'package:generic_search_selector/src/picker_config.dart';
import 'package:generic_search_selector/src/search_anchor_picker.dart';

/// A helper tile that opens a [SearchAnchorPicker] (sub-picker).
///
/// Reduces boilerplate for the common pattern of nested pickers in the header.
/// Can optionally synchronize selection changes with a parent [GenericPickerActions].
class GenericSubPickerTile<T, K> extends StatelessWidget {
  const GenericSubPickerTile({
    super.key,
    required this.title,
    required this.config,
    required this.initialSelectedIds,
    this.icon,
    this.parentActions,
    this.onFinish,
    this.mode = PickerMode.multi,
    this.leading,
    this.subtitle,
    this.trailing,
    this.triggerBuilder,
    this.itemBuilder,
  }) : assert(title != null || triggerBuilder != null);

  /// Title shown on the tile.
  final String? title;

  /// Configuration for the sub-picker.
  final GenericPickerConfig<T, K> config;

  /// IDs that should show as selected when the sub-picker opens.
  final List<K> initialSelectedIds;

  /// Optional parent actions to automatically sync changes to.
  ///
  /// If provided:
  /// - items added in sub-picker are added to parent pending selection.
  /// - items removed in sub-picker are removed from parent pending selection.
  final GenericPickerActions<T, K>? parentActions;

  /// Icon to show leading the tile (convenience for [leading]).
  final IconData? icon;

  final Widget? leading;
  final Widget? subtitle;
  final Widget? trailing;

  final PickerMode mode;

  /// Callback when sub-picker closes.
  /// Run AFTER parent synchronization (if [parentActions] is provided).
  final GenericOnFinish<K>? onFinish;

  /// Optional builder for custom trigger widget.
  ///
  /// If provided, overrides [title], [subtitle], [leading], [trailing].
  /// Receives [open] callback to trigger the picker and [tick] version.
  final Widget Function(BuildContext context, VoidCallback open, int tick)?
  triggerBuilder;

  final Widget Function(
    BuildContext context,
    T item,
    bool isSelected,
    VoidCallback toggle,
  )?
  itemBuilder;

  @override
  Widget build(BuildContext context) {
    return GenericSearchAnchorPicker<T, K>(
      config: config,
      initialSelectedIds: initialSelectedIds,
      onFinish: (ids, {required added, required removed}) async {
        if (parentActions != null) {
          // Sync behavior:
          // 1. If items are removed from sub-list (meaning removed from main list),
          //    we MUST remove them from parent pending selection (can't select what's gone).
          // 2. We do NOT add 'added' items to pending. Default behavior is they enter "unselected".
          final next = {...parentActions!.pending}..removeAll(removed);
          parentActions!.setPending(next);
        }
        if (onFinish != null) {
          await onFinish!(ids, added: added, removed: removed);
        }
      },
      mode: mode,
      itemBuilder: itemBuilder,
      triggerBuilder: (context, open, tick) {
        if (triggerBuilder != null) {
          return triggerBuilder!(context, open, tick);
        }

        return title != null
            ? ListTile(
                leading: leading ?? (icon != null ? Icon(icon) : null),
                onTap: open,
                title: Text(title!),
                subtitle: subtitle,
                trailing: trailing,
                dense: true,
              )
            : const SizedBox(); // Should not happen due to assert
      },
    );
  }
}

class SubPickerTile<T> extends GenericSubPickerTile<T, int> {
  const SubPickerTile({
    super.key,
    required super.title,
    required super.config,
    required super.initialSelectedIds,
    super.icon,
    super.parentActions,
    super.onFinish,
    super.mode,
    super.leading,
    super.subtitle,
    super.trailing,
    super.triggerBuilder,
    super.itemBuilder,
  });
}
