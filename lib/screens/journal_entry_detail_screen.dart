import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/journal_entry.dart';
import '../providers/auth_provider.dart';
import '../providers/journal_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_dialog.dart';
import '../widgets/section_card.dart';

class JournalEntryDetailScreen extends ConsumerStatefulWidget {
  final String entryId;
  const JournalEntryDetailScreen({super.key, required this.entryId});

  @override
  ConsumerState<JournalEntryDetailScreen> createState() =>
      _JournalEntryDetailScreenState();
}

class _JournalEntryDetailScreenState
    extends ConsumerState<JournalEntryDetailScreen> {
  JournalEntry? _entry;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final e =
          await ref.read(journalServiceProvider).getById(widget.entryId);
      setState(() {
        _entry = e;
        _loading = false;
        if (e == null) _error = 'Entry not found';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _post() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Post this journal entry?',
      message:
          'Posted entries cannot be edited — only reversed. Continue?',
      confirmLabel: 'Post',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      await ref.read(journalServiceProvider).post(widget.entryId, uid);
      await _load();
      _snack('Entry posted');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reverse() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reverse this entry?',
      message:
          'A contra entry will be created with debits and credits swapped. The original entry will be marked as reversed.',
      danger: true,
      confirmLabel: 'Reverse',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      await ref.read(journalServiceProvider).reverse(widget.entryId, uid);
      await _load();
      _snack('Reversal created');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this draft?',
      message: 'This cannot be undone.',
      danger: true,
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(journalServiceProvider).deleteDraft(widget.entryId);
      if (mounted) context.go('/accounting/journal');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null || _entry == null) {
      return Center(
        child: Text(_error ?? 'Error', style: AppTextStyles.bodyMedium),
      );
    }
    final e = _entry!;
    final isDraft = e.statusEnum == JournalEntryStatus.draft;
    final isPosted = e.statusEnum == JournalEntryStatus.posted;
    final canReverse =
        isPosted && e.reversedByEntryId == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/accounting/journal'),
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.number, style: AppTextStyles.displayMedium),
                    const SizedBox(height: 4),
                    Text(e.narration,
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              if (isDraft) ...[
                ElevatedButton.icon(
                  onPressed: _busy ? null : _post,
                  icon: _busy
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(LucideIcons.check, size: 16),
                  label: const Text('Post'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(LucideIcons.trash2, size: 15),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ],
              if (canReverse) ...[
                OutlinedButton.icon(
                  onPressed: _busy ? null : _reverse,
                  icon: const Icon(LucideIcons.rotateCcw, size: 15),
                  label: const Text('Reverse'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Details',
            child: _grid([
              _row('Status', journalStatusLabel(e.statusEnum)),
              _row(
                'Date',
                '${e.entryDate.year}-${e.entryDate.month.toString().padLeft(2, '0')}-${e.entryDate.day.toString().padLeft(2, '0')}',
              ),
              _row('Reference',
                  e.reference.isEmpty ? '—' : e.reference),
              if (e.reversalOfEntryId != null)
                _row('Reversal Of', e.reversalOfEntryId!),
              if (e.reversedByEntryId != null)
                _row('Reversed By', e.reversedByEntryId!),
            ]),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Lines',
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 6),
                ...e.lines.asMap().entries.map((ent) {
                  final i = ent.key;
                  final l = ent.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 28,
                            child: Text('${i + 1}',
                                style: AppTextStyles.caption)),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${l.accountCode} — ${l.accountName}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600)),
                              if (l.memo.isNotEmpty)
                                Text(l.memo,
                                    style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            l.debit > 0
                                ? l.debit.toStringAsFixed(2)
                                : '—',
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            l.credit > 0
                                ? l.credit.toStringAsFixed(2)
                                : '—',
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(color: AppColors.border, height: 20),
                Row(
                  children: [
                    const Spacer(),
                    SizedBox(
                      width: 120,
                      child: Text('Total',
                          style: AppTextStyles.label,
                          textAlign: TextAlign.right),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        e.totalDebit.toStringAsFixed(2),
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        e.totalCredit.toStringAsFixed(2),
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<Widget> items) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 700 ? 2 : 1;
      return Wrap(
        spacing: 16,
        runSpacing: 14,
        children: items
            .map((w) => SizedBox(
                  width: (c.maxWidth - (cols - 1) * 16) / cols,
                  child: w,
                ))
            .toList(),
      );
    });
  }

  Widget _row(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.bodyMedium),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        const SizedBox(width: 28),
        Expanded(
            flex: 4,
            child: Text('Account', style: AppTextStyles.label)),
        Expanded(
          flex: 2,
          child: Text('Debit',
              style: AppTextStyles.label, textAlign: TextAlign.right),
        ),
        Expanded(
          flex: 2,
          child: Text('Credit',
              style: AppTextStyles.label, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}