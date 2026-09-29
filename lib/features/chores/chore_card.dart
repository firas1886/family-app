import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../core/text.dart';
import 'repeat_label.dart';

/// Colours for chores that belong to no one yet ("anyone" and former members).
PersonColor neutralPersonColor(ThemeData theme) {
  final scheme = theme.colorScheme;
  return PersonColor(
    fill: scheme.primary,
    onFill: scheme.onPrimary,
    tint: scheme.surfaceContainerHighest,
    onTint: scheme.onSurface,
  );
}

/// A chore in the playful style: tinted in the person's colour until done,
/// then filled. With [pictureTile], a big emoji tile for younger children.
class ChoreCard extends StatelessWidget {
  const ChoreCard({
    super.key,
    required this.status,
    required this.color,
    required this.pictureTile,
    required this.onToggle,
    this.onLongPress,
    this.late = false,
  });

  final ChoreStatus status;
  final PersonColor color;
  final bool pictureTile;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final chore = status.chore;
    final done = status.isDone;
    final background = done ? color.fill : color.tint;
    final foreground = done ? color.onFill : color.onTint;
    final radius = BorderRadius.circular(tokens.tileRadius);
    final caption = choreCaption(context, chore);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
      decoration: done ? TextDecoration.lineThrough : null,
      decorationColor: foreground,
    );
    final captionStyle = theme.textTheme.bodySmall?.copyWith(color: foreground);
    final tick = _TickButton(
      key: ValueKey('tick-${chore.id}'),
      done: done,
      foreground: foreground,
      background: background,
      label: chore.title,
      onTap: onToggle,
    );

    final Widget content;
    if (pictureTile) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            chore.icon ?? tileLetter(chore.title),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 44, height: 1.2, color: foreground, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            chore.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: titleStyle,
          ),
          if (caption.isNotEmpty)
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: captionStyle,
            ),
          tick,
        ],
      );
    } else {
      content = Row(
        children: [
          if (chore.icon != null) ...[
            Text(chore.icon!, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chore.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
                  if (caption.isNotEmpty)
                    Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: captionStyle),
                ],
              ),
            ),
          ),
          tick,
        ],
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: late ? Border.all(color: tokens.late, width: 2) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onToggle,
          // A long press must never count as a tap (Release 1 lesson), so the
          // card claims long presses whenever it handles taps.
          onLongPress: onLongPress ?? (onToggle == null ? null : () {}),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: pictureTile
                  ? const EdgeInsets.fromLTRB(8, 12, 8, 4)
                  : const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 4),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// The round tick: a 48 dp target around a 30 dp circle.
class _TickButton extends StatelessWidget {
  const _TickButton({
    super.key,
    required this.done,
    required this.foreground,
    required this.background,
    required this.label,
    required this.onTap,
  });

  final bool done;
  final Color foreground;
  final Color background;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      checked: done,
      enabled: enabled,
      label: label,
      child: SizedBox(
        width: 48,
        height: 48,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.35,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? foreground : Colors.transparent,
                  border: Border.all(color: foreground, width: 2.5),
                ),
                child: done ? Icon(Icons.check, size: 20, color: background) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Picture tiles in rows of equal height: at least two per row, more when
/// there is room. Rows grow with the text, so nothing can overflow.
class PictureTileGrid extends StatelessWidget {
  const PictureTileGrid({super.key, required this.children, this.minTileWidth = 140, this.spacing = 8});

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = math.max(2, ((constraints.maxWidth + spacing) / (minTileWidth + spacing)).floor());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var start = 0; start < children.length; start += perRow)
              Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < perRow; i++) ...[
                        if (i > 0) SizedBox(width: spacing),
                        Expanded(
                          child: start + i < children.length ? children[start + i] : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
