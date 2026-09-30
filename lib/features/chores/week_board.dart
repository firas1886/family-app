import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../core/dates.dart';
import '../../l10n/app_localizations.dart';
import 'chores_board.dart';

/// One column of the week: a day and its chips, top to bottom.
class WeekDayChips {
  const WeekDayChips({required this.day, required this.chips});

  final DateTime day;
  final List<Widget> chips;
}

/// "Wed 30": the title of a day in the week view.
String weekDayTitle(String locale, DateTime day) => DateFormat('EEE d', locale).format(day);

/// The landscape tablet's week: one column per day (Sunday first, so the
/// right-most column in Arabic), sharing the width evenly. Each column scrolls
/// on its own. Today's column is tinted and its title highlighted; tapping a
/// title opens that day.
///
/// The chips are built by the Chores screen, which decides what a tap and a
/// long press may do; this widget only lays them out.
class WeekBoard extends StatelessWidget {
  const WeekBoard({super.key, required this.days, required this.today, required this.onDayTap});

  final List<WeekDayChips> days;
  final DateTime today;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in days)
          Expanded(
            child: _WeekColumn(
              key: ValueKey('weekColumn-${dateKey(d.day)}'),
              day: d.day,
              chips: d.chips,
              isToday: d.day == today,
              onTitleTap: () => onDayTap(d.day),
            ),
          ),
      ],
    );
  }
}

class _WeekColumn extends StatelessWidget {
  const _WeekColumn({
    super.key,
    required this.day,
    required this.chips,
    required this.isToday,
    required this.onTitleTap,
  });

  final DateTime day;
  final List<Widget> chips;
  final bool isToday;
  final VoidCallback onTitleTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final date = dateKey(day);
    final title = weekDayTitle(l.localeName, day);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
    // Today: a light wash of the theme's primary colour over the card colour.
    final background = isToday ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.08), tokens.card) : tokens.card;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        child: ColoredBox(
          color: background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                selected: isToday,
                child: InkWell(
                  key: ValueKey('weekDayTitle-$date'),
                  onTap: onTitleTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Center(
                        child: isToday
                            ? DecoratedBox(
                                key: const ValueKey('weekToday'),
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: titleStyle?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              )
                            : Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  key: ValueKey('weekList-$date'),
                  // Each day keeps its own scroll position; none of them is the
                  // screen's primary scroll view.
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(6, 2, 6, addButtonClearance),
                  children: [
                    if (chips.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          l.noChores,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedText),
                        ),
                      )
                    else
                      for (final chip in chips) Padding(padding: const EdgeInsets.only(bottom: 6), child: chip),
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

/// A chore in the week view: a small bar in the person's colour, tinted until
/// done, then filled with a ✓. Shows the emoji, the title on one line and the
/// owner's [initial]. [onTap] ticks or unticks; null when this user can't.
class WeekChip extends StatelessWidget {
  const WeekChip({
    super.key,
    required this.status,
    required this.color,
    this.initial,
    required this.onTap,
    this.onLongPress,
  });

  final ChoreStatus status;
  final PersonColor color;

  /// The first letter of the name the owner is shown by ([memberLabel]), or
  /// null for nobody.
  final String? initial;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chore = status.chore;
    final done = status.isDone;
    final background = done ? color.fill : color.tint;
    final foreground = done ? color.onFill : color.onTint;
    final radius = BorderRadius.circular(12);
    final textStyle = theme.textTheme.labelLarge?.copyWith(color: foreground, fontWeight: FontWeight.w600);
    return Semantics(
      button: true,
      checked: done,
      enabled: onTap != null,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          // As on the day cards: a long press must never count as a tap.
          onLongPress: onLongPress ?? (onTap == null ? null : () {}),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 6, 4),
              child: Row(
                children: [
                  if (done) ...[
                    Text('✓', style: textStyle),
                    const SizedBox(width: 4),
                  ],
                  if (chore.icon != null) ...[
                    Text(chore.icon!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(chore.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle),
                  ),
                  if (initial != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: foreground, width: 1.5),
                      ),
                      child: Text(
                        initial!,
                        style: theme.textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
