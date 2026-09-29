import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../l10n/app_localizations.dart';
import 'chore_groups.dart';

/// Space below the last card of every chores list (the phone list and each
/// board column), so the last card can always scroll clear of the add button.
const double addButtonClearance = 96;

/// The landscape tablet board: one column per member plus Anyone, side by
/// side. Each column scrolls on its own. The board scrolls sideways only when
/// the columns can't all get [minColumnWidth].
class ChoresBoard extends StatelessWidget {
  const ChoresBoard({super.key, required this.groups, required this.cardBuilder});

  final List<ChoreGroup> groups;
  final Widget Function(ChoreGroup group, ChoreStatus status) cardBuilder;

  static const double minColumnWidth = 260;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = [
          for (final g in groups)
            _BoardColumn(key: ValueKey('boardColumn-${g.id}'), group: g, cardBuilder: cardBuilder),
        ];
        if (groups.length * minColumnWidth <= constraints.maxWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final c in columns) Expanded(child: c)],
          );
        }
        return SingleChildScrollView(
          key: const Key('boardScroll'),
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            height: constraints.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final c in columns) SizedBox(width: minColumnWidth, child: c)],
            ),
          ),
        );
      },
    );
  }
}

class _BoardColumn extends ConsumerWidget {
  const _BoardColumn({super.key, required this.group, required this.cardBuilder});

  final ChoreGroup group;
  final Widget Function(ChoreGroup group, ChoreStatus status) cardBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final colors = ref.watch(memberColorsProvider);
    final member = group.member;
    final index = member == null ? null : colors[member.uid];
    final accent = index == null ? theme.colorScheme.outlineVariant : personColor(index, theme.brightness).fill;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        child: ColoredBox(
          color: tokens.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(color: accent, child: const SizedBox(height: 4)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: ChoreGroupHeader(group: group),
              ),
              Expanded(
                child: ListView(
                  key: ValueKey('boardList-${group.id}'),
                  // Each column keeps its own scroll position; none of them is
                  // the screen's primary scroll view.
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, addButtonClearance),
                  children: [
                    if (group.items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(l.noChores, style: TextStyle(color: tokens.mutedText)),
                      )
                    else
                      for (final s in group.items)
                        Padding(padding: const EdgeInsets.only(bottom: 8), child: cardBuilder(group, s)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
