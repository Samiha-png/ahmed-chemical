import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/supplier_payment.dart';
import 'sequence_service.dart';
import 'supplier_bill_service.dart';

class SupplierPaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SequenceService _seq = SequenceService();
  final SupplierBillService _bills = SupplierBillService();

  Stream<List<SupplierPayment>> watch({
    String? supplierId,
    String? search,
  }) {
    Query q = _db
        .collection('supplierPayments')
        .orderBy('createdAt', descending: true);
    if (supplierId != null && supplierId.isNotEmpty) {
      q = q.where('supplierId', isEqualTo: supplierId);
    }
    return q.snapshots().map((s) {
      var list = s.docs.map(SupplierPayment.fromDoc).toList();
      if (search != null && search.trim().isNotEmpty) {
        final q2 = search.toLowerCase();
        list = list
            .where((p) =>
                p.number.toLowerCase().contains(q2) ||
                p.supplierName.toLowerCase().contains(q2))
            .toList();
      }
      return list;
    });
  }

  Future<SupplierPayment?> getById(String id) async {
    final doc = await _db.collection('supplierPayments').doc(id).get();
    if (!doc.exists) return null;
    return SupplierPayment.fromDoc(doc);
  }

  /// Post a payment and allocate to bills.
  ///
  /// Validates every allocation, then updates each bill's `amountPaid`.
  Future<String> create({
    required SupplierPayment payment,
  }) async {
    if (payment.amount <= 0) {
      throw Exception('Payment amount must be greater than zero');
    }
    // Validate allocations
    num totalAlloc = 0;
    for (final a in payment.allocations) {
      if (a.amount <= 0) {
        throw Exception('Allocation amount must be positive');
      }
      totalAlloc += a.amount;
    }
    if (totalAlloc > payment.amount + 0.01) {
      throw Exception(
          'Total allocated ($totalAlloc) exceeds payment amount (${payment.amount})');
    }

    // Generate number
    final number = await _seq.next('PAY');

    // Create payment
    final ref = await _db.collection('supplierPayments').add({
      ...payment.toMap(),
      'number': number,
      'status': PaymentStatus.posted.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Apply each allocation to its bill
    for (final a in payment.allocations) {
      if (a.amount <= 0) continue;
      await _bills.addPayment(billId: a.billId, amount: a.amount);
    }

    return ref.id;
  }

  /// Cancel a payment — reverses bill allocations.
  Future<void> cancel(String id) async {
    final payment = await getById(id);
    if (payment == null) return;
    if (payment.statusEnum == PaymentStatus.cancelled) return;

    // Reverse allocations (add back to bill's amountPaid by subtracting)
    for (final a in payment.allocations) {
      if (a.amount <= 0) continue;
      final bill = await _bills.getById(a.billId);
      if (bill == null) continue;
      final newPaid = (bill.amountPaid - a.amount).clamp(0, bill.grandTotal);
      String status = bill.status;
      if (newPaid <= 0.01) {
        status = BillStatusNames.posted;
      } else if (newPaid < bill.grandTotal - 0.01) {
        status = BillStatusNames.partiallyPaid;
      } else {
        status = BillStatusNames.paid;
      }
      await _db.collection('supplierBills').doc(a.billId).update({
        'amountPaid': newPaid,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await _db.collection('supplierPayments').doc(id).update({
      'status': PaymentStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Helper — matches BillStatus enum names for update strings.
class BillStatusNames {
  static const posted = 'posted';
  static const partiallyPaid = 'partiallyPaid';
  static const paid = 'paid';
}