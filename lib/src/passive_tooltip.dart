import 'dart:async';

import 'package:flutter/material.dart';

/// Lightweight tooltip that paints inside the widget subtree instead of a root overlay.
///
/// That keeps the tooltip visually separate while still allowing mouse wheel
/// events to reach the underlying scrollable even when the cursor is over the
/// tooltip bubble.
class PassiveTooltip extends StatefulWidget {
  const PassiveTooltip({
    required this.child,
    required this.message,
    super.key,
    this.waitDuration = const Duration(milliseconds: 500),
    this.exitDuration = const Duration(milliseconds: 200),
    this.verticalGap = 14,
    this.horizontalGap = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.decoration,
    this.textStyle,
  });

  final Widget child;
  final String message;
  final Duration waitDuration;
  final Duration exitDuration;
  final double verticalGap;
  final double horizontalGap;
  final EdgeInsetsGeometry padding;
  final Decoration? decoration;
  final TextStyle? textStyle;

  @override
  State<PassiveTooltip> createState() => _PassiveTooltipState();
}

class _PassiveTooltipState extends State<PassiveTooltip> {
  Timer? _showTimer;
  Timer? _hideTimer;
  bool _visible = false;

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleShow() {
    _hideTimer?.cancel();
    if (_visible) return;
    _showTimer?.cancel();
    _showTimer = Timer(widget.waitDuration, () {
      if (!mounted || _visible) return;
      setState(() => _visible = true);
    });
  }

  void _scheduleHide() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _hideTimer = Timer(widget.exitDuration, () {
      if (!mounted || !_visible) return;
      setState(() => _visible = false);
    });
  }

  Widget _buildBubble(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final decoration =
        widget.decoration ??
        BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(4),
        );
    final textStyle =
        widget.textStyle ??
        textTheme.bodySmall?.copyWith(color: Colors.white);

    return IgnorePointer(
      ignoring: true,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: decoration,
          child: Padding(
            padding: widget.padding,
            child: Text(widget.message, style: textStyle),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onEnter: (_) => _scheduleShow(),
      onExit: (_) => _scheduleHide(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_visible)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Transform.translate(
                    offset: Offset(widget.horizontalGap, -widget.verticalGap),
                    child: _buildBubble(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
