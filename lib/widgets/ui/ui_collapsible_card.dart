import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import 'ui_card.dart';

/// A [UiCard] whose header is the toggle: tapping the title row folds the blurb
/// and body away. The card's own padding lives inside the tap target, so a
/// collapsed card is clickable edge to edge instead of only on the text.
class UiCollapsibleCard extends StatefulWidget {
  final String title;
  final String description;
  final Widget child;
  final double padding;

  const UiCollapsibleCard({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.padding = 20,
  });

  @override
  State<UiCollapsibleCard> createState() => _UiCollapsibleCardState();
}

class _UiCollapsibleCardState extends State<UiCollapsibleCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final pad = widget.padding;
    return UiCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GestureDetector, not InkWell: no hover highlight or splash wanted.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              // Collapsed, the header owns the whole card, so it keeps the
              // bottom padding too.
              padding: EdgeInsets.fromLTRB(pad, pad, pad, _expanded ? 6 : pad),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: ui.display.copyWith(fontSize: 17),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: ui.muted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: ui.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  widget.child,
                ],
              ),
            ),
        ],
      ),
    );
  }
}
