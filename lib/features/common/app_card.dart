import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The app's rounded card. Neutral cards get a hairline border;
/// coloured cards ([color] set) have none.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = BorderRadius.circular(tokens.cardRadius);
    return Material(
      color: color ?? tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: color == null ? BorderSide(color: tokens.cardBorder) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
