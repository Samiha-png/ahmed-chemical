import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/account.dart';
import '../models/journal_entry.dart';
import '../providers/account_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/journal_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/form_field.dart';
import '../widgets/section_card.dart';

class JournalEntryFormScreen extends ConsumerStatefulWidget {
  const JournalEntryFormScreen({super.key});

  @override
  ConsumerState<JournalEntryFormScreen> createState() =>
      _JournalEntryFormScreenState();
}

class _JournalEntryFormScreenState
    extends ConsumerState<JournalEntryFormScreen> {
  final _narrationCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  DateTime _entryDate = DateTime.now();
  final List<_JLineDraft> _lines = [_JLineDraft.empty(), _JLineDraft.empty()];

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _narrationCtrl.dispose();
    _referenceCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  num _parse(String s) => num.tryParse(s.trim()) ?? 0;

  num get _totalDebit =>
      _lines.fold<num>(0, (a, l) => a + _parse(l.debitCtrl.text));
  num get _totalCredit =>
      _lines.fold<num>(0, (a, l) => a + _parse(l.creditCtrl.text));

  bool get _isBalanced =>
      (_totalDebit - _totalCredit).abs() < 0.01 && _totalDebit > 0;

  void _addLine() => setState(() => _lines.add(_JLineDraft.empty()));

  void _removeLine(int i) {
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  Future<void> _save({bool andPost = false}) async {
    if (_narrationCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Narration is required');
      return;
    }
    if (_lines.length < 2) {
      setState(() => _error = 'At least two lines required');
      return;
    }
    final lines = <JournalLine>[];
    for (final l in _lines) {
      if (l.accountId.isEmpty) {
        setState(() => _error = 'Every line needs an account');
        return;
      }
      final dr = _parse(l.debitCtrl.text);
      final cr = _parse(l.creditCtrl.text);
      if (dr == 0 && cr == 0) continue; // skip empty lines
      if (dr > 0 && cr > 0) {
        setState(() => _error = 'A line cannot have both debit and credit');
        return;
      }
      lines.add(JournalLine(
        accountId: l.accountId,
        accountCode: l.accountCode,
        accountName: l.accountName,
        debit: dr,
        credit: cr,
        memo: l.memoCtrl.text.trim(),
      ));
    }
    if (lines.length < 2) {
      setState(() => _error = 'At least two non-empty lines required');
      return;
    }
    final totalDr = lines.fold<num>(0, (a, l) => a + l.debit);
    final totalCr = lines.fold<num>(0, (a, l) => a + l.credit);
    if ((totalDr - totalCr).abs() > 0.01) {
      setState(() => _error =
          'Not balanced. Debit: $totalDr, Credit: $totalCr');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
      final entry = JournalEntry(
        id: '',
        number: '',
        entryDate: _entryDate,
        status: JournalEntryStatus.draft.name,
        narration: _narrationCtrl.text.trim(),
        reference: _referenceCtrl.text.trim(),
        lines: lines,
        createdBy: uid,
      );
      final id =
          await ref.read(journalServiceProvider).createDraft(entry);
      if (andPost) {
        await ref.read(journalServiceProvider).post(id, uid);
      }
      if (mounted) context.go('/accounting/journal');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(chartOfAccountsProvider);

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
              Text('New Journal Entry',
                  style: AppTextStyles.displayMedium),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Entry Details',
            child: Column(
              children: [
                AppFormField(
                  label: 'Narration',
                  controller: _narrationCtrl,
                  hint: 'e.g. Monthly rent for October',
                  icon: LucideIcons.fileText,
                  required: true,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppFormField(
                        label: 'Reference',
                        controller: _referenceCtrl,
                        hint: 'Optional — invoice/bill/PO number',
                        icon: LucideIcons.hash,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entry Date', style: AppTextStyles.label),
                          const SizedBox(height: 6),
                          Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.elevated,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: AppColors.border),
                            ),
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _entryDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (d != null) {
                                  setState(() => _entryDate = d);
                                }
                              },
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.calendar,
                                      size: 15,
                                      color: AppColors.textDim),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_entryDate.year}-${_entryDate.month.toString().padLeft(2, '0')}-${_entryDate.day.toString().padLeft(2, '0')}',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Lines (Debit / Credit)',
            trailing: TextButton.icon(
              onPressed: _addLine,
              icon: const Icon(LucideIcons.plus, size: 14),
              label: const Text('Add Line'),
            ),
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 8),
                ...List.generate(_lines.length, (i) {
                  return _JLineRow(
                    index: i + 1,
                    draft: _lines[i],
                    accounts: accounts,
                    onRemove: _lines.length > 2
                        ? () => _removeLine(i)
                        : null,
                    onChanged: () => setState(() {}),
                  );
                }),
                const SizedBox(height: 12),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Spacer(),
                    SizedBox(
                      width: 140,
                      child: _totLine('Total Debit', _totalDebit),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: _totLine('Total Credit', _totalCredit),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isBalanced
                            ? AppColors.primarySoft
                            : AppColors.errorSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isBalanced ? 'Balanced' : 'Not Balanced',
                        style: AppTextStyles.caption.copyWith(
                          color: _isBalanced
                              ? AppColors.primary
                              : AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(LucideIcons.alertCircle,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.go('/accounting/journal'),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed:
                    _saving ? null : () => _save(andPost: false),
                icon: const Icon(LucideIcons.save, size: 16),
                label: const Text('Save as Draft'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _saving || !_isBalanced
                    ? null
                    : () => _save(andPost: true),
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(LucideIcons.check, size: 16),
                label: Text(_saving ? 'Saving...' : 'Save & Post'),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const SizedBox(width: 28),
        Expanded(
            flex: 4,
            child: Text('Account', style: AppTextStyles.label)),
        const SizedBox(width: 8),
        SizedBox(
            width: 100,
            child: Text('Debit',
                style: AppTextStyles.label, textAlign: TextAlign.right)),
        const SizedBox(width: 8),
        SizedBox(
            width: 100,
            child: Text('Credit',
                style: AppTextStyles.label, textAlign: TextAlign.right)),
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _totLine(String label, num value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text('PKR ${value.toStringAsFixed(2)}',
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _JLineDraft {
  String accountId;
  String accountCode;
  String accountName;
  final TextEditingController debitCtrl;
  final TextEditingController creditCtrl;
  final TextEditingController memoCtrl;

  _JLineDraft({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.debitCtrl,
    required this.creditCtrl,
    required this.memoCtrl,
  });

  factory _JLineDraft.empty() => _JLineDraft(
        accountId: '',
        accountCode: '',
        accountName: '',
        debitCtrl: TextEditingController(),
        creditCtrl: TextEditingController(),
        memoCtrl: TextEditingController(),
      );

  void dispose() {
    debitCtrl.dispose();
    creditCtrl.dispose();
    memoCtrl.dispose();
  }
}

class _JLineRow extends StatelessWidget {
  final int index;
  final _JLineDraft draft;
  final AsyncValue<List<Account>> accounts;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _JLineRow({
    required this.index,
    required this.draft,
    required this.accounts,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
              width: 28,
              child: Text('#$index', style: AppTextStyles.caption)),
          Expanded(
            flex: 4,
            child: accounts.when(
              loading: () => const SizedBox(
                  height: 42, child: LinearProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (list) {
                final validIds = list.map((a) => a.id).toSet();
                final value = validIds.contains(draft.accountId)
                    ? draft.accountId
                    : null;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: value,
                      isExpanded: true,
                      dropdownColor: AppColors.elevated,
                      style: AppTextStyles.bodyMedium,
                      hint: Text('Select account',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textDim)),
                      items: list
                          .map((a) => DropdownMenuItem<String>(
                                value: a.id,
                                child: Text('${a.code} — ${a.name}'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final a = list.firstWhere((x) => x.id == v);
                        draft.accountId = a.id;
                        draft.accountCode = a.code;
                        draft.accountName = a.name;
                        onChanged();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextField(
              controller: draft.debitCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              onChanged: (_) => onChanged(),
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                fillColor: AppColors.card,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextField(
              controller: draft.creditCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              onChanged: (_) => onChanged(),
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                fillColor: AppColors.card,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: onRemove != null
                ? IconButton(
                    onPressed: onRemove,
                    icon: const Icon(LucideIcons.trash2, size: 14),
                    color: AppColors.error,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}