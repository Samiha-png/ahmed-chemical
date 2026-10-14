import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sales_order.dart';
import 'sequence_service.dart';

class SalesOrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SequenceService _seq = SequenceService();

  Stream<List<SalesOrder>> watch({
    String? status,
    String? customerId,
    String? search,
  }) {
    Query q = _db
        .collection('salesOrders')
        .orderBy('createdAt', descending: true);
    if (status != null && status.isNotEmpty) {
      q = q.where('status', isEqualTo: status);
    }
    if (customerId != null && customerId.isNotEmpty) {
      q = q.where('customerId', isEqualTo: customerId);
    }
    return q.snapshots().map((s) {
      var list = s.docs.map(SalesOrder.fromDoc).toList();
      if (search != null && search.trim().isNotEmpty) {
        final q2 = search.toLowerCase();
        list = list
            .where((p) =>
                p.number.toLowerCase().contains(q2) ||
                p.customerName.toLowerCase().contains(q2))
            .toList();
      }
      return list;
    });
  }

  Future<SalesOrder?> getById(String id) async {
    final doc = await _db.collection('salesOrders').doc(id).get();
    if (!doc.exists) return null;
    return SalesOrder.fromDoc(doc);
  }

  Future<String> create(SalesOrder so) async {
    final number = await _seq.next('SO');
    final ref = await _db.collection('salesOrders').add({
      ...so.toMap(),
      'number': number,
      'status': SOStatus.draft.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String id, SalesOrder so) async {
    final current = await getById(id);
    if (current == null) throw Exception('Sales order not found');
    if (current.statusEnum != SOStatus.draft) {
      throw Exception('Only draft sales orders can be edited');
    }
    await _db.collection('salesOrders').doc(id).update({
      ...so.toMap(),
      'number': current.number,
      'status': current.status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> confirm(String id, String userId) async {
    final current = await getById(id);
    if (current == null) throw Exception('Sales order not found');
    if (current.statusEnum != SOStatus.draft) {
      throw Exception('Only draft sales orders can be confirmed');
    }
    if (current.lines.isEmpty) {
      throw Exception('Cannot confirm an empty sales order');
    }
    await _db.collection('salesOrders').doc(id).update({
      'status': SOStatus.confirmed.name,
      'confirmedBy': userId,
      'confirmedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancel(String id, String userId) async {
    final current = await getById(id);
    if (current == null) throw Exception('Sales order not found');
    if (current.statusEnum == SOStatus.invoiced ||
        current.statusEnum == SOStatus.closed) {
      throw Exception('Cannot cancel an invoiced/closed sales order');
    }
    await _db.collection('salesOrders').doc(id).update({
      'status': SOStatus.cancelled.name,
      'cancelledBy': userId,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    final current = await getById(id);
    if (current == null) return;
    if (current.statusEnum != SOStatus.draft) {
      throw Exception('Only draft sales orders can be deleted');
    }
    await _db.collection('salesOrders').doc(id).delete();
  }

  /// Update the SO after an invoice is posted.
  /// Recomputes invoicedQuantity per line and updates status.
  Future<void> markInvoiced({
    required String soId,
    required Map<String, num> invoicedByLineId,
  }) async {
    final so = await getById(soId);
    if (so == null) return;

    final updatedLines = <SOLine>[];
    bool allFullyInvoiced = true;
    for (final line in so.lines) {
      final added = invoicedByLineId[line.id] ?? 0;
      final newInv = line.invoicedQuantity + added;
      updatedLines.add(SOLine(
        id: line.id,
        productId: line.productId,
        productName: line.productName,
        sku: line.sku,
        baseUnit: line.baseUnit,
        warehouseId: line.warehouseId,
        warehouseName: line.warehouseName,
        quantity: line.quantity,
        unitPrice: line.unitPrice,
        discountPercent: line.discountPercent,
        taxPercent: line.taxPercent,
        invoicedQuantity: newInv,
      ));
      if (newInv < line.quantity) allFullyInvoiced = false;
    }

    final newStatus = allFullyInvoiced
        ? SOStatus.invoiced.name
        : SOStatus.partiallyInvoiced.name;

    await _db.collection('salesOrders').doc(soId).update({
      'lines': updatedLines.map((l) => l.toMap()).toList(),
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}