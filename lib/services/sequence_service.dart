import 'package:cloud_firestore/cloud_firestore.dart';

/// Central sequence service for auto-numbering documents.
///
/// Format: {PREFIX}-{YEAR}-{NNNN}
/// Example: PO-2026-0001, INV-2026-0042, GRN-2026-0007
///
/// Each sequence is stored in `sequences/{key}` document:
///   { current: 0, year: 2026 }
///
/// Uses a Firestore transaction to guarantee uniqueness under concurrency.
class SequenceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> next(String prefix) async {
    final year = DateTime.now().year;
    final key = '${prefix}_$year';
    final ref = _db.collection('sequences').doc(key);

    final nextVal = await _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      int current = 0;
      int storedYear = year;
      if (snap.exists) {
        final d = snap.data() as Map<String, dynamic>;
        current = (d['current'] ?? 0) as int;
        storedYear = (d['year'] ?? year) as int;
      }
      // Reset if year changed
      if (storedYear != year) {
        current = 0;
      }
      final next = current + 1;
      tx.set(ref, {
        'current': next,
        'year': year,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return next;
    });

    final num = nextVal.toString().padLeft(4, '0');
    return '$prefix-$year-$num';
  }
}