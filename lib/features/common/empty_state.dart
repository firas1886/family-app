import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A friendly "nothing here" block: big emoji, a title, an optional message
/// and an optional action button. Place it inside a scrollable parent.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.title, this.message, this.action});

  final String emoji;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Text(emoji, style: const TextStyle(fontSize: 48))),
          const SizedBox(height: 12),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              style: text.bodyMedium?.copyWith(color: context.tokens.mutedText),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
