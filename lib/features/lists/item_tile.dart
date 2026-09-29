import 'package:flutter/material.dart';

import '../../core/text.dart';

class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.name,
    required this.color,
    this.caption = '',
    this.dimmed = false,
    this.highlighted = false,
    this.onTap,
    this.onLongPress,
  });

  final String name;
  final Color color;
  final String caption;
  final bool dimmed;
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    // Text colour follows the tile colour, so light tiles (the catalog's
    // card colour in the light theme) get dark text.
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final onColorMuted = onColor.withValues(alpha: 0.72);
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          border: Border.all(
            color: highlighted ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
            width: 3,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(6),
              // Keeps the width (so the name still wraps to 2 lines) and scales
              // the whole column down when a small phone or large text would
              // otherwise push the quantity out of the tile.
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: onColorMuted,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              tileLetter(name),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: onColor,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: onColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (caption.isNotEmpty)
                            Text(
                              caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: onColorMuted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
