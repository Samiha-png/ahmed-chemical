import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/purchase_order.dart';
import 'sequence_service.dart';

class PurchaseOrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SequenceService _seq = SequenceService();

  Stream<List<PurchaseOrder>> watch({
    String? status,
    String? supplierId,
    String? search,
  }) {
    Query q = _db
        .collection('purchaseOrders')
        .orderBy('createdAt', descending: true);
    if (status != null && status.isNotEmpty) {
      q = q.where('status', isEqualTo: status);
    }
    if (supplierId != null && supplierId.isNotEmpty) {
      q = q.where('supplierId', isEqualTo: supplierId);
    }
    return q.snapshots().map((s) {
      var list = s.docs.map(PurchaseOrder.fromDoc).toList();
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

  Future<PurchaseOrder?> getById(String id) async {
    final doc = await _db.collection('purchaseOrders').doc(id).get();
    if (!doc.exists) return null;
    return PurchaseOrder.fromDoc(doc);
  }

  /// Create a new PO. Generates a unique number.
  Future<String> create(PurchaseOrder po) async {
    final number = await _seq.next('PO');
    final ref = await _db.collection('purchaseOrders').add({
      ...po.toMap(),
      'number': number,
      'status': POStatus.draft.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Update a PO. Only allowed while in `draft`.
  Future<void> update(String id, PurchaseOrder po) async {
    final current = await getById(id);
    if (current == null) throw Exception('PO not found');
    if (current.statusEnum != POStatus.draft) {
      throw Exception('Only draft POs can be edited');
    }
    await _db.collection('purchaseOrders').doc(id).update({
      ...po.toMap(),
      'number': current.number, // never change
      'status': current.status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Approve a draft PO. Records approver uid.
  Future<void> approve(String id, String approverUid) async {
    final current = await getById(id);
    if (current == null) throw Exception('PO not found');
    if (current.statusEnum != POStatus.draft) {
      throw Exception('Only draft POs can be approved');
    }
    if (current.lines.isEmpty) {
      throw Exception('Cannot approve an empty PO');
    }
    await _db.collection('purchaseOrders').doc(id).update({
      'status': POStatus.approved.name,
      'approvedBy': approverUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel an approved or draft PO.
  Future<void> cancel(String id, String userId) async {
    final current = await getById(id);
    if (current == null) throw Exception('PO not found');
    if (current.statusEnum == POStatus.received ||
        current.statusEnum == POStatus.closed) {
      throw Exception('Cannot cancel a received/closed PO');
    }
    await _db.collection('purchaseOrders').doc(id).update({
      'status': POStatus.cancelled.name,
      'cancelledBy': userId,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a draft PO. Approved POs must be cancelled, not deleted.
  Future<void> delete(String id) async {
    final current = await getById(id);
    if (current == null) return;
    if (current.statusEnum != POStatus.draft) {
      throw Exception('Only draft POs can be deleted');
    }
    await _db.collection('purchaseOrders').doc(id).delete();
  }
}