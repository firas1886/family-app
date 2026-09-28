import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/dialogs.dart';
import '../common/offline_chip.dart';
import 'list_screen.dart';

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final isParent = ref.watch(isParentProvider);
    final lists = ref.watch(listsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.tabLists), actions: const [OfflineChip()]),
      floatingActionButton: isParent
          ? FloatingActionButton.extended(
              key: const Key('newListFab'),
              onPressed: () => _create(context, ref, l),
              icon: const Icon(Icons.add),
              label: Text(l.newList),
            )
          : null,
      body: lists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l.somethingWentWrong)),
        data: (lists) => lists.isEmpty
            ? Center(child: Text(isParent ? l.noListsParent : l.noListsChild))
            : ListView(
                children: [
                  for (final list in lists)
                    ListTile(
                      title: Text(list.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => ListScreen(listId: list.id)),
                      ),
                      onLongPress: isParent ? () => _manage(context, ref, list, l) : null,
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final name = await promptText(context, title: l.newList, label: l.listName, confirmLabel: l.create);
    final uid = ref.read(currentUidProvider);
    if (name == null || name.trim().isEmpty || uid == null) return;
    fireAndForget(ref.read(listRepositoryProvider).createList(name: name, uid: uid));
  }

  Future<void> _manage(BuildContext context, WidgetRef ref, ShoppingList list, AppLocalizations l) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l.rename),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(l.delete),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final repo = ref.read(listRepositoryProvider);
    if (action == 'rename') {
      final name = await promptText(context,
          title: l.rename, label: l.listName, initial: list.name, confirmLabel: l.save);
      if (name != null && name.trim().isNotEmpty) fireAndForget(repo.renameList(list.id, name));
      return;
    }
    if (await confirm(context, message: l.confirmDeleteList(list.name), confirmLabel: l.delete)) {
      fireAndForget(repo.deleteList(list.id));
    }
  }
}
