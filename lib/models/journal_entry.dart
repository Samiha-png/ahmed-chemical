import 'package:cloud_firestore/cloud_firestore.dart';

enum JournalEntryStatus {
  draft,
  posted,
  reversed,
}

String journalStatusLabel(JournalEntryStatus s) {
  switch (s) {
    case JournalEntryStatus.draft:
      return 'Draft';
    case JournalEntryStatus.posted:
      return 'Posted';
    case JournalEntryStatus.reversed:
      return 'Reversed';
  }
}

class JournalLine {
  final String accountId;
  final String accountCode;
  final String accountName;
  final num debit;
  final num credit;
  final String memo;

  JournalLine({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.debit,
    required this.credit,
    this.memo = '',
  });

  Map<String, dynamic> toMap() => {
        'accountId': accountId,
        'accountCode': accountCode,
        'accountName': accountName,
        'debit': debit,
        'credit': credit,
        'memo': memo,
      };

  factory JournalLine.fromMap(Map<String, dynamic> m) => JournalLine(
        accountId: m['accountId'] ?? '',
        accountCode: m['accountCode'] ?? '',
        accountName: m['accountName'] ?? '',
        debit: (m['debit'] ?? 0) as num,
        credit: (m['credit'] ?? 0) as num,
        memo: m['memo'] ?? '',
      );
}

class JournalEntry {
  final String id;
  final String number;       // JE-2026-0001
  final DateTime entryDate;
  final String status;       // draft, posted, reversed
  final String narration;    // overall description
  final String reference;    // optional — invoice/PO/bill number
  final List<JournalLine> lines;

  // Posting metadata
  final String createdBy;
  final String postedBy;
  final DateTime? createdAt;
  final DateTime? postedAt;

  // Reversal metadata
  final String? reversalOfEntryId;   // points to original if this is a reversal
  final String? reversedByEntryId;   // points to reversal if this was reversed
  final DateTime? reversedAt;

  JournalEntry({
    required this.id,
    required this.number,
    required this.entryDate,
    required this.status,
    required this.narration,
    this.reference = '',
    required this.lines,
    this.createdBy = '',
    this.postedBy = '',
    this.createdAt,
    this.postedAt,
    this.reversalOfEntryId,
    this.reversedByEntryId,
    this.reversedAt,
  });

  JournalEntryStatus get statusEnum => JournalEntryStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => JournalEntryStatus.draft,
      );

  num get totalDebit =>
      lines.fold<num>(0, (a, l) => a + l.debit);
  num get totalCredit =>
      lines.fold<num>(0, (a, l) => a + l.credit);

  /// Whether debits equal credits (allow 0.01 rounding).
  bool get isBalanced =>
      (totalDebit - totalCredit).abs() < 0.01;

  factory JournalEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JournalEntry(
      id: doc.id,
      number: d['number'] ?? '',
      entryDate: (d['entryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] ?? 'draft',
      narration: d['narration'] ?? '',
      reference: d['reference'] ?? '',
      lines: (d['lines'] as List<dynamic>? ?? [])
          .map((e) => JournalLine.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdBy: d['createdBy'] ?? '',
      postedBy: d['postedBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      postedAt: (d['postedAt'] as Timestamp?)?.toDate(),
      reversalOfEntryId: d['reversalOfEntryId'],
      reversedByEntryId: d['reversedByEntryId'],
      reversedAt: (d['reversedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'number': number,
        'entryDate': Timestamp.fromDate(entryDate),
        'status': status,
        'narration': narration,
        'reference': reference,
        'lines': lines.map((l) => l.toMap()).toList(),
        'createdBy': createdBy,
        'postedBy': postedBy,
        'reversalOfEntryId': reversalOfEntryId,
        'reversedByEntryId': reversedByEntryId,
      };
}