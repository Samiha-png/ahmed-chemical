import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/journal_entry.dart';
import 'sequence_service.dart';

class JournalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SequenceService _seq = SequenceService();

  Stream<List<JournalEntry>> watch({
    JournalEntryStatus? status,
    DateTime? from,
    DateTime? to,
    String? search,
  }) {
    Query q = _db
        .collection('journalEntries')
        .orderBy('entryDate', descending: true);
    if (status != null) q = q.where('status', isEqualTo: status.name);
    return q.snapshots().map((s) {
      var list = s.docs.map(JournalEntry.fromDoc).toList();
      if (from != null) {
        list = list.where((e) => !e.entryDate.isBefore(from)).toList();
      }
      if (to != null) {
        list = list
            .where((e) => !e.entryDate.isAfter(
                to.add(const Duration(days: 1))))
            .toList();
      }
      if (search != null && search.trim().isNotEmpty) {
        final q2 = search.toLowerCase();
        list = list
            .where((e) =>
                e.number.toLowerCase().contains(q2) ||
                e.narration.toLowerCase().contains(q2) ||
                e.reference.toLowerCase().contains(q2))
            .toList();
      }
      return list;
    });
  }

  Future<JournalEntry?> getById(String id) async {
    final doc = await _db.collection('journalEntries').doc(id).get();
    if (!doc.exists) return null;
    return JournalEntry.fromDoc(doc);
  }

  /// Create draft entry. Number generated on create.
  Future<String> createDraft(JournalEntry entry) async {
    final number = await _seq.next('JE');
    final ref = await _db.collection('journalEntries').add({
      ...entry.toMap(),
      'number': number,
      'status': JournalEntryStatus.draft.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Post a draft entry. Validates debit == credit.
  Future<void> post(String id, String userId) async {
    final entry = await getById(id);
    if (entry == null) throw Exception('Journal entry not found');
    if (entry.statusEnum != JournalEntryStatus.draft) {
      throw Exception('Only draft entries can be posted');
    }
    if (entry.lines.length < 2) {
      throw Exception('At least two lines required for double-entry');
    }
    if (!entry.isBalanced) {
      throw Exception(
          'Entry is not balanced. Debits: ${entry.totalDebit}, Credits: ${entry.totalCredit}');
    }
    for (final l in entry.lines) {
      if (l.debit < 0 || l.credit < 0) {
        throw Exception('Debit/Credit cannot be negative');
      }
      if (l.debit > 0 && l.credit > 0) {
        throw Exception('A line cannot have both debit and credit');
      }
    }
    await _db.collection('journalEntries').doc(id).update({
      'status': JournalEntryStatus.posted.name,
      'postedBy': userId,
      'postedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reverse a posted entry by creating a contra entry with swapped debits/credits.
  Future<String> reverse(String originalId, String userId) async {
    final original = await getById(originalId);
    if (original == null) throw Exception('Journal entry not found');
    if (original.statusEnum != JournalEntryStatus.posted) {
      throw Exception('Only posted entries can be reversed');
    }
    if (original.reversedByEntryId != null) {
      throw Exception('Entry is already reversed');
    }

    final reversedLines = original.lines
        .map((l) => JournalLine(
              accountId: l.accountId,
              accountCode: l.accountCode,
              accountName: l.accountName,
              debit: l.credit,
              credit: l.debit,
              memo: l.memo,
            ))
        .toList();

    final number = await _seq.next('JE');
    final reversalRef = await _db.collection('journalEntries').add({
      'number': number,
      'entryDate': Timestamp.fromDate(DateTime.now()),
      'status': JournalEntryStatus.posted.name,
      'narration': 'Reversal of ${original.number} — ${original.narration}',
      'reference': original.number,
      'lines': reversedLines.map((l) => l.toMap()).toList(),
      'createdBy': userId,
      'postedBy': userId,
      'reversalOfEntryId': originalId,
      'createdAt': FieldValue.serverTimestamp(),
      'postedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Mark original as reversed
    await _db.collection('journalEntries').doc(originalId).update({
      'status': JournalEntryStatus.reversed.name,
      'reversedByEntryId': reversalRef.id,
      'reversedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return reversalRef.id;
  }

  Future<void> deleteDraft(String id) async {
    final entry = await getById(id);
    if (entry == null) return;
    if (entry.statusEnum != JournalEntryStatus.draft) {
      throw Exception('Only draft entries can be deleted');
    }
    await _db.collection('journalEntries').doc(id).delete();
  }
}