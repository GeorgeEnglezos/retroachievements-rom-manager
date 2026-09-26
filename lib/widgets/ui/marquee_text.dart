import 'package:flutter/material.dart';
import 'ui_focusable.dart';

/// One line of text that ellipsizes at rest and, while the enclosing
/// [UiFocusable] is hovered or focused, rolls right to left in an endless
/// loop (the title, a gap, the title again) so a clipped title can be read.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const MarqueeText(this.text, {super.key, this.style});

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  static const _pixelsPerSecond = 40.0;
  static const _gap = 32.0;

  late final _ctrl = AnimationController(vsync: this);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plain = Text(
      widget.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
    if (!UiFocusable.litOf(context)) {
      _ctrl.stop();
      return plain;
    }
    return LayoutBuilder(
      builder: (context, c) {
        final tp = TextPainter(
          text: TextSpan(
            text: widget.text,
            style: DefaultTextStyle.of(context).style.merge(widget.style),
          ),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final width = tp.width;
        tp.dispose();
        if (width <= c.maxWidth) return plain;

        // One lap: the text plus the gap, after which the trailing copy sits
        // exactly where the first started, so the loop has no visible seam.
        final lap = width + _gap;
        if (!_ctrl.isAnimating) {
          _ctrl
            ..duration = Duration(
              milliseconds: (lap / _pixelsPerSecond * 1000).round(),
            )
            ..value = 0
            ..repeat();
        }
        final text = Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          style: widget.style,
        );
        return UnconstrainedBox(
          alignment: AlignmentDirectional.centerStart,
          constrainedAxis: Axis.vertical,
          clipBehavior: Clip.hardEdge,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(-lap * _ctrl.value, 0),
              child: child,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [text, const SizedBox(width: _gap), text],
            ),
          ),
        );
      },
    );
  }
}
