import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/supplier_bill.dart';
import 'sequence_service.dart';

class SupplierBillService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SequenceService _seq = SequenceService();

  Stream<List<SupplierBill>> watch({
    String? status,
    String? supplierId,
    String? search,
  }) {
    Query q = _db
        .collection('supplierBills')
        .orderBy('createdAt', descending: true);
    if (status != null && status.isNotEmpty) {
      q = q.where('status', isEqualTo: status);
    }
    if (supplierId != null && supplierId.isNotEmpty) {
      q = q.where('supplierId', isEqualTo: supplierId);
    }
    return q.snapshots().map((s) {
      var list = s.docs.map(SupplierBill.fromDoc).toList();
      if (search != null && search.trim().isNotEmpty) {
        final q2 = search.toLowerCase();
        list = list
            .where((b) =>
                b.number.toLowerCase().contains(q2) ||
                b.supplierName.toLowerCase().contains(q2) ||
                b.supplierBillNumber.toLowerCase().contains(q2))
            .toList();
      }
      return list;
    });
  }

  Future<SupplierBill?> getById(String id) async {
    final doc = await _db.collection('supplierBills').doc(id).get();
    if (!doc.exists) return null;
    return SupplierBill.fromDoc(doc);
  }

  Future<String> createDraft(SupplierBill bill) async {
    final number = await _seq.next('BILL');
    final ref = await _db.collection('supplierBills').add({
      ...bill.toMap(),
      'number': number,
      'status': BillStatus.draft.name,
      'amountPaid': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Post a bill — no stock changes (stock already increased by GRN).
  /// This just marks it as a liability.
  Future<void> post({
    required String billId,
    required String userId,
  }) async {
    final bill = await getById(billId);
    if (bill == null) throw Exception('Bill not found');
    if (bill.statusEnum != BillStatus.draft) {
      throw Exception('Only draft bills can be posted');
    }
    if (bill.lines.isEmpty) {
      throw Exception('Cannot post an empty bill');
    }
    await _db.collection('supplierBills').doc(billId).update({
      'status': BillStatus.posted.name,
      'postedBy': userId,
      'postedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Record a payment against this bill. Called by SupplierPaymentService.
  Future<void> addPayment({
    required String billId,
    required num amount,
  }) async {
    final bill = await getById(billId);
    if (bill == null) throw Exception('Bill not found');
    if (bill.statusEnum == BillStatus.cancelled) {
      throw Exception('Cannot pay a cancelled bill');
    }
    if (amount <= 0) {
      throw Exception('Payment amount must be greater than zero');
    }
    final newPaid = bill.amountPaid + amount;
    if (newPaid > bill.grandTotal + 0.01) {
      throw Exception(
          'Payment exceeds bill total (outstanding: ${bill.outstanding})');
    }
    String status = bill.status;
    if (newPaid >= bill.grandTotal - 0.01) {
      status = BillStatus.paid.name;
    } else if (newPaid > 0) {
      status = BillStatus.partiallyPaid.name;
    }
    await _db.collection('supplierBills').doc(billId).update({
      'amountPaid': newPaid,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelDraft(String id) async {
    final bill = await getById(id);
    if (bill == null) return;
    if (bill.statusEnum != BillStatus.draft) {
      throw Exception('Only draft bills can be cancelled');
    }
    await _db.collection('supplierBills').doc(id).update({
      'status': BillStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDraft(String id) async {
    final bill = await getById(id);
    if (bill == null) return;
    if (bill.statusEnum != BillStatus.draft) {
      throw Exception('Only draft bills can be deleted');
    }
    await _db.collection('supplierBills').doc(id).delete();
  }
}