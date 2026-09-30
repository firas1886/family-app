import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../core/dates.dart';
import '../../core/member_names.dart';
import '../../core/models.dart';
import '../../core/text.dart';
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
import 'week_board.dart';
import 'who_did_it.dart';

/// From this available width the Chores tab shows the tablet board.
const boardBreakpoint = 840.0;

/// What the Chores tab shows: one day, or (on the landscape tablet only) the
/// week around it.
enum ChoresView { day, week }

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

  /// Day or Week. Only the landscape tablet shows the week; narrower screens
  /// always show one day but keep this choice, so rotating back returns to it.
  ChoresView _view = ChoresView.day;

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
    final weekStart = startOfWeek(day);
    // The week view reads the whole week's done records in one query.
    final weekDoneAsync = _view == ChoresView.week
        ? ref.watch(choreDoneProvider((from: dateKey(weekStart), to: dateKey(addDays(weekStart, 6)))))
        : null;

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

    Widget weekContent() {
      final weekDone = weekDoneAsync!;
      if (me != null && membersAsync.hasValue && choresAsync.hasValue && weekDone.hasValue) {
        return _week(
          l,
          weekStart: weekStart,
          today: today,
          me: me,
          isParent: isParent,
          onlyMe: onlyMe,
          colors: colors,
          members: membersAsync.requireValue,
          chores: choresAsync.requireValue,
          done: weekDone.requireValue,
        );
      }
      if (membersAsync.hasError || choresAsync.hasError || weekDone.hasError) {
        return Center(child: Text(l.somethingWentWrong));
      }
      return const Center(child: CircularProgressIndicator());
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Day | Week is offered on the landscape tablet only; below the
          // breakpoint the screen always shows one day.
          final wide = constraints.maxWidth >= boardBreakpoint;
          final view = wide ? _view : ChoresView.day;
          return Column(
            children: [
              _dayBar(l, day, today, onlyMe, view: view, showViewToggle: wide),
              Expanded(child: view == ChoresView.week ? weekContent() : content),
            ],
          );
        },
      ),
    );
  }

  Widget _dayBar(
    AppLocalizations l,
    DateTime day,
    DateTime today,
    bool onlyMe, {
    required ChoresView view,
    required bool showViewToggle,
  }) {
    final material = MaterialLocalizations.of(context);
    final week = view == ChoresView.week;
    // A week moves by seven days; the picked or shown day selects its week.
    final step = week ? DateTime.daysPerWeek : 1;
    final weekStart = startOfWeek(day);
    final label = week
        ? l.weekRange(shortDate(l.localeName, weekStart), shortDate(l.localeName, addDays(weekStart, 6)))
        : (day == today ? l.today : dayTitle(l.localeName, day));
    final scope = SegmentedButton<bool>(
      key: const Key('choresScope'),
      expandedInsets: EdgeInsets.zero,
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: false, label: Text(l.everyone)),
        ButtonSegment(value: true, label: Text(l.me)),
      ],
      selected: {onlyMe},
      onSelectionChanged: (selection) => setState(() => _onlyMe = selection.first),
    );
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
                onPressed: () => setState(() => _day = addDays(day, -step)),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('dayLabel'),
                  onPressed: () => _pickDay(day, today),
                  child: Text(
                    label,
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
                onPressed: () => setState(() => _day = addDays(day, step)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (showViewToggle)
            Row(
              children: [
                Expanded(child: scope),
                const SizedBox(width: 12),
                SegmentedButton<ChoresView>(
                  key: const Key('choresView'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: ChoresView.day, label: Text(l.viewDay)),
                    ButtonSegment(value: ChoresView.week, label: Text(l.viewWeek)),
                  ],
                  selected: {view},
                  onSelectionChanged: (selection) => setState(() => _view = selection.first),
                ),
              ],
            )
          else
            scope,
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
    return ChoreCard(
      key: ValueKey('chore-${chore.id}'),
      status: status,
      color: _colorFor(info, group, status),
      pictureTile: group.member?.pictureTiles ?? false,
      onToggle: _onToggle(info, group, status),
      onLongPress: _onEdit(info, status),
    );
  }

  /// The week view on the landscape tablet: seven day columns, Sunday first.
  /// Each day holds its chores for the groups on show, in group order, as
  /// [buildChoreGroups] gives them for the Everyone / Me choice.
  Widget _week(
    AppLocalizations l, {
    required DateTime weekStart,
    required DateTime today,
    required String me,
    required bool isParent,
    required bool onlyMe,
    required Map<String, int> colors,
    required List<Member> members,
    required List<Chore> chores,
    required List<ChoreDone> done,
  }) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final memberUids = {for (final m in members) m.uid};
    final choreIds = {for (final c in chores) c.id};
    final days = <WeekDayChips>[];
    for (var i = 0; i < DateTime.daysPerWeek; i++) {
      final date = addDays(weekStart, i);
      final view = choresForDay(
        chores: chores,
        done: done,
        memberUids: memberUids,
        day: date,
        languageCode: languageCode,
      );
      final info = _DayInfo(
        day: date,
        today: today,
        me: me,
        isParent: isParent,
        colors: colors,
        choreIds: choreIds,
      );
      final groups = buildChoreGroups(view: view, members: members, me: me, isParent: isParent, onlyMe: onlyMe);
      days.add(WeekDayChips(
        day: date,
        chips: [
          for (final g in groups)
            for (final s in g.items) _weekChip(info, g, s, members),
        ],
      ));
    }
    if (days.every((d) => d.chips.isEmpty)) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, addButtonClearance),
        children: [EmptyState(emoji: '🎉', title: l.noChores)],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      child: WeekBoard(
        days: days,
        today: today,
        onDayTap: (date) => setState(() {
          _day = date;
          _view = ChoresView.day;
        }),
      ),
    );
  }

  /// A chore in the week view. Colour, tap and long press follow the same
  /// rules as the day cards ([_colorFor], [_onToggle], [_onEdit]).
  Widget _weekChip(_DayInfo info, ChoreGroup group, ChoreStatus status, List<Member> members) {
    final chore = status.chore;
    // The person whose colour the chip wears: the member, or for Anyone and
    // former-member chores whoever did it.
    final owner = group.member ?? memberById(members, status.done?.doneBy);
    return WeekChip(
      key: ValueKey('weekChip-${chore.id}-${dateKey(info.day)}'),
      status: status,
      color: _colorFor(info, group, status),
      initial: owner == null ? null : tileLetter(memberLabel(owner)),
      onTap: _onToggle(info, group, status),
      onLongPress: _onEdit(info, status),
    );
  }

  /// Whether I may tick or untick [status] on [info]'s day. The one rule for
  /// the day cards and the week chips.
  bool _canTick(_DayInfo info, ChoreStatus status) {
    final chore = status.chore;
    final exists = info.choreIds.contains(chore.id);
    // A child can untick only a tick they made themselves (spec §8). Anyone
    // else's tick shows as done but can't be changed by the child.
    final mayChange = !status.isDone || info.isParent || status.done!.doneBy == info.me;
    return exists &&
        mayChange &&
        canToggle(chore: chore, isParent: info.isParent, me: info.me, day: info.day, today: info.today);
  }

  /// Ticks or unticks through [toggleChore]; null when [_canTick] says no.
  VoidCallback? _onToggle(_DayInfo info, ChoreGroup group, ChoreStatus status) => _canTick(info, status)
      ? () => toggleChore(
            context,
            ref,
            status: status,
            day: info.day,
            siblings: group.member == null ? const [] : group.items,
          )
      : null;

  /// Opens the chore sheet: parents for any chore, a child for a chore they
  /// made for themselves. Never for a deleted chore's stand-in.
  VoidCallback? _onEdit(_DayInfo info, ChoreStatus status) {
    final chore = status.chore;
    final exists = info.choreIds.contains(chore.id);
    final canEdit = exists && (info.isParent || (chore.createdBy == info.me && chore.assignee == info.me));
    return canEdit ? () => showChoreSheet(context, chore: chore, day: info.day) : null;
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
