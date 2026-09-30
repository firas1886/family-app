import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/reminder_scheduler.dart';
import '../../l10n/app_localizations.dart';

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? label,
  String? helper,
  String initial = '',
  required String confirmLabel,
  TextInputType? keyboardType,
  int? maxLength,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      helper: helper,
      initial: initial,
      confirmLabel: confirmLabel,
      keyboardType: keyboardType,
      maxLength: maxLength,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.helper,
    required this.initial,
    required this.confirmLabel,
    required this.keyboardType,
    required this.maxLength,
  });
  final String title;
  final String? label;
  final String? helper;
  final String initial;
  final String confirmLabel;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('promptField'),
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        maxLength: widget.maxLength,
        decoration: InputDecoration(labelText: widget.label, helperText: widget.helper, helperMaxLines: 3),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          key: const Key('promptConfirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String message,
  required String confirmLabel,
}) async {
  final l = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l.cancel)),
        FilledButton(
          key: const Key('confirmYes'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Saved on this phone once Android has been asked to allow notifications.
const notificationsAskedKey = 'notificationsAsked';

/// The app's one way to ask for permission to show chore reminders.
///
/// Android is asked only the first time on each phone (remembered under
/// [notificationsAskedKey]), so a phone never gets the prompt twice. After
/// that, this only checks. If notifications are off, it explains how to turn
/// them on in the phone's settings. With [firstTimeOnly] (used by
/// ReminderSync), it does nothing once this phone has been asked.
Future<void> askReminderPermission(
  BuildContext context,
  ReminderScheduler scheduler,
  SharedPreferences prefs, {
  bool firstTimeOnly = false,
}) async {
  final asked = prefs.getBool(notificationsAskedKey) == true;
  if (asked && firstTimeOnly) return;
  final bool granted;
  if (asked) {
    granted = await scheduler.notificationsEnabled();
  } else {
    // Saved before asking, so a second caller in the meantime doesn't ask again.
    unawaited(prefs.setBool(notificationsAskedKey, true));
    granted = await scheduler.requestPermission();
  }
  if (granted || !context.mounted) return;
  final l = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('notificationsDenied'),
      content: Text(l.notificationsDenied),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
        ),
      ],
    ),
  );
}
