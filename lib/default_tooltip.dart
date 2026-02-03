import 'package:flutter/material.dart';

/// Text that shows a Tooltip only when it overflows (ellipsis is applied).
class OverflowTooltipText extends StatelessWidget {
  const OverflowTooltipText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
    this.tooltip,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  /// If provided, this string is used for the tooltip instead of [text].
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: text, style: style ?? DefaultTextStyle.of(context).style);
        final tp = TextPainter(
          text: span,
          maxLines: maxLines,
          textDirection: Directionality.of(context),
          textAlign: textAlign ?? TextAlign.start,
          ellipsis: '…',
        )..layout(maxWidth: constraints.maxWidth);

        final didOverflow = tp.didExceedMaxLines;

        final child = Text(
          text,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
        );

        if (!didOverflow) return child;

        return Tooltip(
          message: tooltip ?? text,
          child: child,
        );
      },
    );
  }
}
