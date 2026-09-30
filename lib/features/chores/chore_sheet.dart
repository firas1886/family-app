import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/chores.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/text.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/dialogs.dart';
import 'chore_groups.dart';
import 'repeat_label.dart';

/// Opens the chore sheet: a new chore starting on [day] when [chore] is null,
/// otherwise [chore] for editing.
Future<void> showChoreSheet(BuildContext context, {Chore? chore, required DateTime day}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ChoreSheet(chore: chore, day: day),
  );
}

class ChoreSheet extends ConsumerStatefulWidget {
  const ChoreSheet({super.key, this.chore, required this.day});

  final Chore? chore;
  final DateTime day;

  @override
  ConsumerState<ChoreSheet> createState() => _ChoreSheetState();
}

class _ChoreSheetState extends ConsumerState<ChoreSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.chore?.title ?? '');
  late final TextEditingController _emoji = TextEditingController(text: widget.chore?.icon ?? '');
  late final TextEditingController _every = TextEditingController(text: '${widget.chore?.every ?? 1}');
  late final TextEditingController _monthDay =
      TextEditingController(text: '${widget.chore?.monthDay ?? widget.day.day}');
  late bool _whoChosen = widget.chore != null;
  late String? _assignee = widget.chore?.assignee;
  late String? _time = widget.chore?.time;
  late Repeat _repeat = widget.chore?.repeat ?? Repeat.daily;
  late final Set<int> _weekdays = {...?widget.chore?.weekdays};
  late DateTime _start = widget.chore == null ? dayOnly(widget.day) : parseDateKey(widget.chore!.startDate);
  late DateTime? _end = _initialEnd();
  late bool _remind = widget.chore?.remind ?? false;
  bool _showProblems = false;

  DateTime? _initialEnd() {
    final end = widget.chore?.endDate;
    return end == null ? null : parseDateKey(end);
  }

  @override
  void dispose() {
    _title.dispose();
    _emoji.dispose();
    _every.dispose();
    _monthDay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final me = ref.watch(currentUidProvider) ?? '';
    final isParent = ref.watch(isParentProvider);
    final members = [...(ref.watch(membersProvider).valueOrNull ?? const <Member>[])]..sort(compareMembers);
    final assignee = _effectiveAssignee(me, isParent, members);
    final draft = _draft(me, assignee);
    final problems = _showProblems ? validateChore(draft) : const <ChoreProblem>{};
    final chore = widget.chore;
    final canDelete = chore != null && (isParent || (chore.createdBy == me && chore.assignee == me));
    final whoOptions = isParent
        ? members
        : [
            for (final m in members)
              if (m.uid == me) m,
          ];
    final errorStyle = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(chore == null ? l.addChore : l.editChore, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const Key('choreTitle'),
              controller: _title,
              maxLength: maxChoreTitleLength,
              // Longer titles are not cut off: Save explains the limit instead.
              maxLengthEnforcement: MaxLengthEnforcement.none,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.choreTitle,
                // The length Save checks (validateChore), where an emoji counts 2.
                counterText: '${_title.text.trim().length}/$maxChoreTitleLength',
                errorText: problems.contains(ChoreProblem.blankTitle)
                    ? l.problemBlankTitle
                    : problems.contains(ChoreProblem.titleTooLong)
                        ? l.problemTitleTooLong
                        : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('choreEmoji'),
              controller: _emoji,
              decoration: InputDecoration(labelText: l.choreEmoji, hintText: '🧹'),
              onChanged: _keepOneEmoji,
            ),
            const SizedBox(height: 16),
            Text(l.who, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in whoOptions)
                  ChoiceChip(
                    key: ValueKey('choreWho-${m.uid}'),
                    label: Text(m.name),
                    selected: assignee == m.uid,
                    onSelected: (_) => setState(() {
                      _whoChosen = true;
                      _assignee = m.uid;
                    }),
                  ),
                if (isParent)
                  ChoiceChip(
                    key: const ValueKey('choreWho-anyone'),
                    label: Text(l.anyone),
                    selected: assignee == null,
                    onSelected: (_) => setState(() {
                      _whoChosen = true;
                      _assignee = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _TapField(
              key: const Key('choreTime'),
              label: l.time,
              value: _time == null ? l.noTime : formatChoreTime(context, _time!),
              onTap: _pickTime,
              trailing: _time == null
                  ? null
                  : IconButton(
                      key: const Key('choreTimeClear'),
                      tooltip: l.noTime,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _time = null;
                        _remind = false;
                      }),
                    ),
            ),
            const SizedBox(height: 16),
            Text(l.repeat, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final r in Repeat.values)
                  ChoiceChip(
                    key: ValueKey('choreRepeat-${r.name}'),
                    label: Text(_repeatName(l, r)),
                    selected: _repeat == r,
                    onSelected: (_) => _setRepeat(r),
                  ),
              ],
            ),
            if (_repeat != Repeat.once) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('choreEvery'),
                controller: _every,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.every,
                  helperText: repeatLabel(l, draft), // live preview: "Every 2 weeks · Mon, Thu"
                  helperMaxLines: 2,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_repeat == Repeat.weekly) ...[
              const SizedBox(height: 12),
              Text(l.onDays, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final d in weekOrder)
                    FilterChip(
                      key: ValueKey('choreWeekday-$d'),
                      label: Text(weekdayName(l, d)),
                      selected: _weekdays.contains(d),
                      onSelected: (on) => setState(() => on ? _weekdays.add(d) : _weekdays.remove(d)),
                    ),
                ],
              ),
              if (problems.contains(ChoreProblem.weeklyNoDays))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l.problemWeeklyNoDays, style: errorStyle),
                ),
            ],
            if (_repeat == Repeat.monthly) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('choreMonthDay'),
                controller: _monthDay,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.dayOfMonth,
                  errorText: problems.contains(ChoreProblem.badMonthDay) ? l.problemBadMonthDay : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            _TapField(
              key: const Key('choreStart'),
              label: l.startDate,
              value: longDate(l.localeName, _start),
              onTap: _pickStart,
            ),
            if (_repeat != Repeat.once) ...[
              SwitchListTile(
                key: const Key('choreEndNever'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.endsNever),
                value: _end == null,
                onChanged: (never) => setState(() => _end = never ? null : _start),
              ),
              if (_end != null)
                _TapField(
                  key: const Key('choreEndDate'),
                  label: l.endDate,
                  value: longDate(l.localeName, _end!),
                  onTap: _pickEnd,
                  errorText: problems.contains(ChoreProblem.endBeforeStart) ? l.problemEndBeforeStart : null,
                ),
            ],
            SwitchListTile(
              key: const Key('choreRemind'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.remind),
              value: _remind && _time != null,
              onChanged: _time == null ? null : _setRemind,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (canDelete)
                  TextButton(
                    key: const Key('choreDelete'),
                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    onPressed: () => _delete(l),
                    child: Text(l.delete),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('choreSave'),
                  onPressed: () => _save(me, assignee),
                  child: Text(l.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Children always make chores for themselves. A parent's new chore starts
  /// with the first child until the parent picks someone.
  String? _effectiveAssignee(String me, bool isParent, List<Member> members) {
    if (!isParent) return me;
    if (_whoChosen) return _assignee;
    for (final m in members) {
      if (m.role == Role.child) return m.uid;
    }
    return me;
  }

  Chore _draft(String me, String? assignee) {
    final emoji = _emoji.text.trim();
    final typedEvery = parseNumber(_every.text)?.round() ?? 1;
    final every = typedEvery < 1 ? 1 : (typedEvery > 99 ? 99 : typedEvery);
    return Chore(
      id: widget.chore?.id ?? '',
      title: _title.text.trim(),
      icon: emoji.isEmpty ? null : emoji.characters.first,
      assignee: assignee,
      time: _time,
      repeat: _repeat,
      every: _repeat == Repeat.once ? 1 : every,
      weekdays: _repeat == Repeat.weekly ? (_weekdays.toList()..sort()) : const [],
      monthDay: _repeat == Repeat.monthly ? parseNumber(_monthDay.text)?.round() : null,
      startDate: dateKey(_start),
      endDate: _repeat == Repeat.once || _end == null ? null : dateKey(_end!),
      remind: _remind && _time != null,
      createdBy: widget.chore?.createdBy ?? me,
    );
  }

  /// The emoji field holds one emoji: typing another replaces it.
  void _keepOneEmoji(String value) {
    final chars = value.trim().characters;
    if (chars.length > 1) {
      final last = chars.last;
      _emoji.value = TextEditingValue(text: last, selection: TextSelection.collapsed(offset: last.length));
    }
    setState(() {});
  }

  void _setRepeat(Repeat repeat) {
    setState(() {
      _repeat = repeat;
      if (repeat == Repeat.weekly && _weekdays.isEmpty) _weekdays.add(_start.weekday);
    });
  }

  void _setRemind(bool on) {
    setState(() => _remind = on);
    if (on) askReminderPermission(context, ref.read(reminderSchedulerProvider), ref.read(sharedPreferencesProvider));
  }

  String _repeatName(AppLocalizations l, Repeat r) => switch (r) {
        Repeat.once => l.repeatOnce,
        Repeat.daily => l.repeatDaily,
        Repeat.weekly => l.repeatWeekly,
        Repeat.monthly => l.repeatMonthly,
      };

  Future<void> _pickTime() async {
    final current = _time == null ? null : parseChoreTime(_time!);
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = choreTimeKey(picked));
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
        currentDate: ref.read(todayProvider),
      );

  Future<void> _pickStart() async {
    final picked = await _pickDate(_start);
    if (picked == null || !mounted) return;
    setState(() => _start = dayOnly(picked));
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDate(_end ?? _start);
    if (picked == null || !mounted) return;
    setState(() => _end = dayOnly(picked));
  }

  void _save(String me, String? assignee) {
    final draft = _draft(me, assignee);
    if (validateChore(draft).isNotEmpty) {
      setState(() => _showProblems = true);
      return;
    }
    final repo = ref.read(choreRepositoryProvider);
    if (widget.chore == null) {
      fireAndForget(repo.addChore(draft));
    } else {
      fireAndForget(repo.updateChore(draft));
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete(AppLocalizations l) async {
    final chore = widget.chore!;
    final ok = await confirm(context, message: l.confirmDeleteChore(chore.title), confirmLabel: l.delete);
    if (!ok || !mounted) return;
    fireAndForget(ref.read(choreRepositoryProvider).deleteChore(chore.id));
    Navigator.of(context).pop();
  }
}

/// A read-only field that opens a picker when tapped.
class _TapField extends StatelessWidget {
  const _TapField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
    this.errorText,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, errorText: errorText, suffixIcon: trailing),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
