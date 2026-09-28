import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';

class OfflineChip extends ConsumerWidget {
  const OfflineChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineProvider).valueOrNull ?? false;
    if (!offline) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Chip(
        avatar: const Icon(Icons.cloud_off, size: 16),
        label: Text(AppLocalizations.of(context)!.offline),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
