import 'package:flutter/material.dart';
import 'package:generic_search_selector/src/picker_config.dart';
import 'package:generic_search_selector/src/search_anchor_picker.dart';

/// A helper tile that opens a [SearchAnchorPicker] (sub-picker).
///
/// Reduces boilerplate for the common pattern of nested pickers in the header.
/// Can optionally synchronize selection changes with a parent [PickerActions].
class SubPickerTile<T> extends StatelessWidget {
  const SubPickerTile({
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
  });

  /// Title shown on the tile.
  final String title;

  /// Configuration for the sub-picker.
  final PickerConfig<T> config;

  /// IDs that should show as selected when the sub-picker opens.
  final List<int> initialSelectedIds;

  /// Optional parent actions to automatically sync changes to.
  ///
  /// If provided:
  /// - items added in sub-picker are added to parent pending selection.
  /// - items removed in sub-picker are removed from parent pending selection.
  final PickerActions<T>? parentActions;

  /// Icon to show leading the tile (convenience for [leading]).
  final IconData? icon;

  final Widget? leading;
  final Widget? subtitle;
  final Widget? trailing;

  final PickerMode mode;

  /// Callback when sub-picker closes.
  /// Run AFTER parent synchronization (if [parentActions] is provided).
  final OnFinish? onFinish;

  @override
  Widget build(BuildContext context) {
    return SearchAnchorPicker<T>(
      config: config,
      initialSelectedIds: initialSelectedIds,
      mode: mode,
      triggerChild: ListTile(
        leading: leading ?? (icon != null ? Icon(icon) : null),
        title: Text(title),
        subtitle: subtitle,
        trailing: trailing,
        dense: true,
      ),
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
    );
  }
}
