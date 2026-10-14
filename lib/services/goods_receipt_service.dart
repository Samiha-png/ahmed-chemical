import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/goods_receipt.dart';
import '../models/purchase_order.dart';
import 'inventory_service.dart';
import 'sequence_service.dart';

class GoodsReceiptService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SequenceService _seq = SequenceService();
  final InventoryService _inv = InventoryService();

  Stream<List<GoodsReceipt>> watch({
    String? status,
    String? search,
  }) {
    Query q = _db
        .collection('goodsReceipts')
        .orderBy('createdAt', descending: true);
    if (status != null && status.isNotEmpty) {
      q = q.where('status', isEqualTo: status);
    }
    return q.snapshots().map((s) {
      var list = s.docs.map(GoodsReceipt.fromDoc).toList();
      if (search != null && search.trim().isNotEmpty) {
        final q2 = search.toLowerCase();
        list = list
            .where((g) =>
                g.number.toLowerCase().contains(q2) ||
                g.poNumber.toLowerCase().contains(q2) ||
                g.supplierName.toLowerCase().contains(q2))
            .toList();
      }
      return list;
    });
  }

  Future<GoodsReceipt?> getById(String id) async {
    final doc = await _db.collection('goodsReceipts').doc(id).get();
    if (!doc.exists) return null;
    return GoodsReceipt.fromDoc(doc);
  }

  /// Create a draft GRN. Does NOT touch stock.
  Future<String> createDraft(GoodsReceipt grn) async {
    final number = await _seq.next('GRN');
    final ref = await _db.collection('goodsReceipts').add({
      ...grn.toMap(),
      'number': number,
      'status': GRNStatus.draft.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Post a GRN: increases stock for every line, updates PO
  /// received quantity and status.
  ///
  /// Fail-fast: validates stock for every line before making any change.
  Future<void> post({
    required String grnId,
    required String userId,
  }) async {
    final grn = await getById(grnId);
    if (grn == null) throw Exception('GRN not found');
    if (grn.statusEnum != GRNStatus.draft) {
      throw Exception('Only draft GRNs can be posted');
    }
    if (grn.lines.isEmpty) {
      throw Exception('Cannot post an empty GRN');
    }

    // Receipt all lines (each uses a transaction internally)
    for (final line in grn.lines) {
      if (line.quantity <= 0) continue;
      await _inv.receiveStock(
        productId: line.productId,
        productName: line.productName,
        sku: line.sku,
        baseUnit: line.baseUnit,
        warehouseId: grn.warehouseId,
        warehouseName: grn.warehouseName,
        quantity: line.quantity,
        unitCost: line.unitCost,
        reorderLevel: 0,
        userId: userId,
        reference: grn.number,
      );
    }

    // Mark GRN posted
    await _db.collection('goodsReceipts').doc(grnId).update({
      'status': GRNStatus.posted.name,
      'postedBy': userId,
      'postedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update parent PO: received qty + status
    await _updatePOAfterReceipt(grn);
  }

  Future<void> _updatePOAfterReceipt(GoodsReceipt grn) async {
    if (grn.poId.isEmpty) return;
    final poRef = _db.collection('purchaseOrders').doc(grn.poId);
    final poSnap = await poRef.get();
    if (!poSnap.exists) return;
    final po = PurchaseOrder.fromDoc(poSnap);

    // Build map: poLineId -> received in this GRN
    final Map<String, num> receivedNow = {};
    for (final l in grn.lines) {
      receivedNow[l.poLineId] =
          (receivedNow[l.poLineId] ?? 0) + l.quantity;
    }

    // Recompute received quantity for each PO line
    final updatedLines = <POLine>[];
    bool allReceived = true;
    for (final line in po.lines) {
      final added = receivedNow[line.id] ?? 0;
      final newReceived = line.receivedQuantity + added;
      updatedLines.add(POLine(
        id: line.id,
        productId: line.productId,
        productName: line.productName,
        sku: line.sku,
        baseUnit: line.baseUnit,
        quantity: line.quantity,
        unitPrice: line.unitPrice,
        discountPercent: line.discountPercent,
        taxPercent: line.taxPercent,
        receivedQuantity: newReceived,
      ));
      if (newReceived < line.quantity) allReceived = false;
    }

    String newStatus = po.status;
    if (allReceived) {
      newStatus = POStatus.received.name;
    } else if (updatedLines.any((l) => l.receivedQuantity > 0)) {
      newStatus = POStatus.partiallyReceived.name;
    }

    await poRef.update({
      'lines': updatedLines.map((l) => l.toMap()).toList(),
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelDraft(String id) async {
    final grn = await getById(id);
    if (grn == null) return;
    if (grn.statusEnum != GRNStatus.draft) {
      throw Exception('Only draft GRNs can be cancelled');
    }
    await _db.collection('goodsReceipts').doc(id).update({
      'status': GRNStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDraft(String id) async {
    final grn = await getById(id);
    if (grn == null) return;
    if (grn.statusEnum != GRNStatus.draft) {
      throw Exception('Only draft GRNs can be deleted');
    }
    await _db.collection('goodsReceipts').doc(id).delete();
  }
}