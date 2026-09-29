import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/member_avatar.dart';

/// Asks a parent who did an "anyone" chore. Null when the sheet is closed.
Future<Member?> showWhoDidIt(BuildContext context, List<Member> members) {
  return showModalBottomSheet<Member>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final l = AppLocalizations.of(sheetContext)!;
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.whoDidIt, style: Theme.of(sheetContext).textTheme.titleLarge),
          ),
          for (final m in members)
            ListTile(
              key: ValueKey('whoDid-${m.uid}'),
              leading: MemberAvatar(member: m),
              title: Text(m.name),
              onTap: () => Navigator.of(sheetContext).pop(m),
            ),
        ],
      );
    },
  );
}
