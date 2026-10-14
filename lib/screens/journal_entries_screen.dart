import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/journal_entry.dart';
import '../providers/journal_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';

class JournalEntriesScreen extends ConsumerWidget {
  const JournalEntriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(journalEntriesProvider);
    final search = ref.watch(journalSearchProvider);
    final status = ref.watch(journalStatusFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Journal Entries',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Manual and auto-generated double-entry records.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/accounting/journal/new'),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('New Entry'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(LucideIcons.search,
                          size: 15, color: AppColors.textDim),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => ref
                              .read(journalSearchProvider.notifier)
                              .state = v,
                          style: AppTextStyles.bodyMedium,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText:
                                'Search by number, narration, or reference...',
                            hintStyle: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textDim),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<JournalEntryStatus?>(
                    value: status,
                    dropdownColor: AppColors.elevated,
                    style: AppTextStyles.bodyMedium,
                    hint: Text('All statuses',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textDim)),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All statuses')),
                      ...JournalEntryStatus.values.map((s) =>
                          DropdownMenuItem(
                            value: s,
                            child: Text(journalStatusLabel(s)),
                          )),
                    ],
                    onChanged: (v) => ref
                        .read(journalStatusFilterProvider.notifier)
                        .state = v,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: entries.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: AppTextStyles.bodySmall),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: LucideIcons.bookOpen,
                      title: search.isEmpty && status == null
                          ? 'No journal entries yet'
                          : 'No matching entries',
                      message: search.isEmpty && status == null
                          ? 'Create a manual journal entry to get started.'
                          : 'Adjust your filters or search.',
                      actionLabel: search.isEmpty && status == null
                          ? 'New Entry'
                          : null,
                      onAction: search.isEmpty && status == null
                          ? () =>
                              context.go('/accounting/journal/new')
                          : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final e = list[i];
                      return ListTile(
                        onTap: () => context
                            .go('/accounting/journal/${e.id}'),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _statusColor(e.statusEnum)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _statusColor(e.statusEnum)
                                    .withValues(alpha: 0.35)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _statusIcon(e.statusEnum),
                            size: 16,
                            color: _statusColor(e.statusEnum),
                          ),
                        ),
                        title: Text(
                          '${e.number}  •  ${e.narration}',
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${journalStatusLabel(e.statusEnum)}  •  ${e.lines.length} line(s)  •  ${_fmtDate(e.entryDate)}',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Text(
                          'PKR ${e.totalDebit.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Color _statusColor(JournalEntryStatus s) {
    switch (s) {
      case JournalEntryStatus.draft:
        return AppColors.textDim;
      case JournalEntryStatus.posted:
        return AppColors.primary;
      case JournalEntryStatus.reversed:
        return AppColors.error;
    }
  }

  IconData _statusIcon(JournalEntryStatus s) {
    switch (s) {
      case JournalEntryStatus.draft:
        return LucideIcons.fileEdit;
      case JournalEntryStatus.posted:
        return LucideIcons.checkCircle;
      case JournalEntryStatus.reversed:
        return LucideIcons.rotateCcw;
    }
  }
}