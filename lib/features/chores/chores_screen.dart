import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../../data/chore_repository.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/empty_state.dart';
import '../common/offline_chip.dart';
import 'celebration.dart';
import 'chore_card.dart';
import 'chore_groups.dart';
import 'chore_sheet.dart';
import 'chores_board.dart';
import 'late_strip.dart';
import 'repeat_label.dart';
import 'who_did_it.dart';

/// From this available width the Chores tab shows the tablet board.
const boardBreakpoint = 840.0;

/// Ticks or unticks one chore for [day]. Every screen with chore cards ticks
/// through here. Writes go through [fireAndForget] and are never awaited.
///
/// A parent ticking an "anyone" chore is asked who did it; a child is recorded
/// as themselves. A tick celebrates, and the celebration is the big one when the
/// tick completes all of [siblings] (that person's chores for the day).
Future<void> toggleChore(
  BuildContext context,
  WidgetRef ref, {
  required ChoreStatus status,
  required DateTime day,
  List<ChoreStatus> siblings = const [],
}) async {
  final me = ref.read(currentUidProvider);
  if (me == null) return;
  final repo = ref.read(choreRepositoryProvider);
  final chore = status.chore;
  final date = dateKey(day);
  final isParent = ref.read(isParentProvider);
  if (status.isDone) {
    // Children untick only their own ticks; the rules refuse the rest.
    if (!isParent && status.done!.doneBy != me) return;
    fireAndForget(repo.untick(choreId: chore.id, date: date));
    return;
  }
  final members = [...(ref.read(membersProvider).valueOrNull ?? const <Member>[])]..sort(compareMembers);
  final now = ref.read(clockProvider)();
  final String doneBy;
  if (chore.isAnyone && isParent) {
    final who = await showWhoDidIt(context, members);
    if (!context.mounted) return;
    if (who == null) return;
    doneBy = who.uid;
  } else {
    // A parent ticking someone's chore records that person; otherwise it's me.
    doneBy = isParent && chore.assignee != null ? chore.assignee! : me;
  }
  fireAndForget(repo.tick(
    chore: chore,
    date: date,
    doneBy: doneBy,
    doneByName: memberById(members, doneBy)?.name ?? '',
    now: now,
  ));
  final big = !chore.isAnyone &&
      siblings.isNotEmpty &&
      siblings.every((s) => s.isDone || s.chore.id == chore.id);
  celebrate(context, big: big);
  _showTicked(context, repo, chore, date);
}

/// "Brush teeth done · Undo", like buying in a shopping list.
void _showTicked(BuildContext context, ChoreRepository repo, Chore chore, String date) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final l = AppLocalizations.of(context)!;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      // A SnackBar with an action stays until dismissed unless persist is false.
      persist: false,
      duration: const Duration(seconds: 5),
      content: Text(l.choreTicked(chore.title)),
      action: SnackBarAction(
        label: l.undo,
        onPressed: () => fireAndForget(repo.untick(choreId: chore.id, date: date)),
      ),
    ));
}

class ChoresScreen extends ConsumerStatefulWidget {
  const ChoresScreen({super.key});

  @override
  ConsumerState<ChoresScreen> createState() => _ChoresScreenState();
}

/// What every card on the screen needs to know about the day on show.
class _DayInfo {
  const _DayInfo({
    required this.day,
    required this.today,
    required this.me,
    required this.isParent,
    required this.colors,
    required this.choreIds,
  });

  final DateTime day;
  final DateTime today;
  final String me;
  final bool isParent;
  final Map<String, int> colors;

  /// Chores that still exist. A deleted chore's done day comes back from
  /// `choresForDay` as a stand-in, which stays read-only.
  final Set<String> choreIds;

  bool get isToday => day == today;
}

class _ChoresScreenState extends ConsumerState<ChoresScreen> {
  DateTime? _day; // null: follow today
  bool? _onlyMe; // null: children start on Me, parents on Everyone

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final today = ref.watch(todayProvider);
    final day = _day ?? today;
    final me = ref.watch(currentUidProvider);
    final isParent = ref.watch(isParentProvider);
    final onlyMe = _onlyMe ?? !isParent;
    final colors = ref.watch(memberColorsProvider);
    final membersAsync = ref.watch(membersProvider);
    final choresAsync = ref.watch(choresProvider);
    final key = dateKey(day);
    final doneAsync = ref.watch(choreDoneProvider((from: key, to: key)));

    final Widget content;
    if (me != null && membersAsync.hasValue && choresAsync.hasValue && doneAsync.hasValue) {
      final members = membersAsync.requireValue;
      final chores = choresAsync.requireValue;
      final view = choresForDay(
        chores: chores,
        done: doneAsync.requireValue,
        memberUids: {for (final m in members) m.uid},
        day: day,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      final info = _DayInfo(
        day: day,
        today: today,
        me: me,
        isParent: isParent,
        colors: colors,
        choreIds: {for (final c in chores) c.id},
      );
      final groups = buildChoreGroups(view: view, members: members, me: me, isParent: isParent, onlyMe: onlyMe);
      content = LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth >= boardBreakpoint && groups.any((g) => g.items.isNotEmpty)
                ? _board(info, groups, onlyMe)
                : _phoneList(l, info, groups, onlyMe),
      );
    } else if (membersAsync.hasError || choresAsync.hasError || doneAsync.hasError) {
      content = Center(child: Text(l.somethingWentWrong));
    } else {
      content = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.tabChores), actions: const [OfflineChip()]),
      floatingActionButton: FloatingActionButton(
        key: const Key('addChore'),
        // The Lists tab's button sits in the same IndexedStack: two buttons with
        // the default hero tag break every page pushed from the shell.
        heroTag: 'addChore',
        tooltip: l.addChore,
        onPressed: () => showChoreSheet(context, day: day),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _dayBar(l, day, today, onlyMe),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _dayBar(AppLocalizations l, DateTime day, DateTime today, bool onlyMe) {
    final material = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('dayPrev'),
                tooltip: material.previousPageTooltip,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _day = addDays(day, -1)),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('dayLabel'),
                  onPressed: () => _pickDay(day, today),
                  child: Text(
                    day == today ? l.today : dayTitle(l.localeName, day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                key: const Key('dayNext'),
                tooltip: material.nextPageTooltip,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _day = addDays(day, 1)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SegmentedButton<bool>(
            key: const Key('choresScope'),
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(l.everyone)),
              ButtonSegment(value: true, label: Text(l.me)),
            ],
            selected: {onlyMe},
            onSelectionChanged: (selection) => setState(() => _onlyMe = selection.first),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDay(DateTime day, DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      currentDate: today,
    );
    if (picked != null && mounted) setState(() => _day = dayOnly(picked));
  }

  Widget _phoneList(AppLocalizations l, _DayInfo info, List<ChoreGroup> groups, bool onlyMe) {
    final allEmpty = groups.every((g) => g.items.isEmpty);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, addButtonClearance), // room for the add button
      children: [
        if (info.isToday) LateStrip(onlyMine: onlyMe),
        if (allEmpty)
          EmptyState(emoji: '🎉', title: info.isToday ? l.noChoresToday : l.noChores)
        else
          for (final g in groups) _section(l, info, g),
      ],
    );
  }

  Widget _board(_DayInfo info, List<ChoreGroup> groups, bool onlyMe) {
    return Column(
      children: [
        if (info.isToday)
          ConstrainedBox(
            // The board keeps most of the height; a long late list scrolls.
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              primary: false,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LateStrip(onlyMine: onlyMe),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: ChoresBoard(groups: groups, cardBuilder: (group, status) => _card(info, group, status)),
          ),
        ),
      ],
    );
  }

  Widget _section(AppLocalizations l, _DayInfo info, ChoreGroup group) {
    final cards = [for (final s in group.items) _card(info, group, s)];
    return Padding(
      key: ValueKey('choreSection-${group.id}'),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoreGroupHeader(group: group),
          const SizedBox(height: 8),
          if (cards.isEmpty)
            Text(l.noChores, style: TextStyle(color: context.tokens.mutedText))
          else if (group.member?.pictureTiles ?? false)
            PictureTileGrid(children: cards)
          else
            for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: card),
        ],
      ),
    );
  }

  Widget _card(_DayInfo info, ChoreGroup group, ChoreStatus status) {
    final chore = status.chore;
    final exists = info.choreIds.contains(chore.id);
    // A child can untick only a tick they made themselves (spec §8). Anyone
    // else's tick shows as done but can't be changed by the child.
    final mayChange = !status.isDone || info.isParent || status.done!.doneBy == info.me;
    final canTick = exists &&
        mayChange &&
        canToggle(chore: chore, isParent: info.isParent, me: info.me, day: info.day, today: info.today);
    final canEdit = exists && (info.isParent || (chore.createdBy == info.me && chore.assignee == info.me));
    return ChoreCard(
      key: ValueKey('chore-${chore.id}'),
      status: status,
      color: _colorFor(info, group, status),
      pictureTile: group.member?.pictureTiles ?? false,
      onToggle: canTick
          ? () => toggleChore(
                context,
                ref,
                status: status,
                day: info.day,
                siblings: group.member == null ? const [] : group.items,
              )
          : null,
      onLongPress: canEdit ? () => showChoreSheet(context, chore: chore, day: info.day) : null,
    );
  }

  /// Member chores wear the member's colour. "Anyone" and former-member chores
  /// take the colour of whoever did them, and a neutral one until then.
  PersonColor _colorFor(_DayInfo info, ChoreGroup group, ChoreStatus status) {
    final theme = Theme.of(context);
    final uid = group.member?.uid ?? status.done?.doneBy;
    final index = uid == null ? null : info.colors[uid];
    return index == null ? neutralPersonColor(theme) : personColor(index, theme.brightness);
  }
}
