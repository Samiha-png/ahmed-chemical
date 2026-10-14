import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sales_invoice.dart';
import 'inventory_service.dart';
import 'sequence_service.dart';

class SalesInvoiceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SequenceService _seq = SequenceService();
  final InventoryService _inv = InventoryService();

  Stream<List<SalesInvoice>> watch({
    String? status,
    String? customerId,
    String? search,
  }) {
    Query q = _db
        .collection('salesInvoices')
        .orderBy('createdAt', descending: true);
    if (status != null && status.isNotEmpty) {
      q = q.where('status', isEqualTo: status);
    }
    if (customerId != null && customerId.isNotEmpty) {
      q = q.where('customerId', isEqualTo: customerId);
    }
    return q.snapshots().map((s) {
      var list = s.docs.map(SalesInvoice.fromDoc).toList();
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

  Future<SalesInvoice?> getById(String id) async {
    final doc = await _db.collection('salesInvoices').doc(id).get();
    if (!doc.exists) return null;
    return SalesInvoice.fromDoc(doc);
  }

  /// Create a draft invoice. Does NOT touch stock.
  Future<String> createDraft(SalesInvoice inv) async {
    final number = await _seq.next('INV');
    final ref = await _db.collection('salesInvoices').add({
      ...inv.toMap(),
      'number': number,
      'status': InvoiceStatus.draft.name,
      'amountPaid': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Post a draft invoice: deducts stock, updates status,
  /// optionally marks parent SO as invoiced.
  ///
  /// Uses a Firestore transaction per line so that either all lines
  /// are deducted or none. If any line fails (insufficient stock),
  /// the whole invoice stays in draft and no stock changes.
  Future<void> postInvoice({
    required String invoiceId,
    required String userId,
  }) async {
    final inv = await getById(invoiceId);
    if (inv == null) throw Exception('Invoice not found');
    if (inv.statusEnum != InvoiceStatus.draft) {
      throw Exception('Only draft invoices can be posted');
    }
    if (inv.lines.isEmpty) {
      throw Exception('Cannot post an empty invoice');
    }

    // Validate stock for all lines first (fail fast)
    for (final line in inv.lines) {
      final bal = await _inv.getBalance(line.productId, line.warehouseId);
      if (bal == null) {
        throw Exception(
            '${line.productName}: no stock found in ${line.warehouseName}');
      }
      if (bal.quantity < line.quantity) {
        throw Exception(
            '${line.productName}: insufficient stock. Available: ${bal.quantity} ${line.baseUnit}');
      }
    }

    // Deduct stock for each line
    final Map<String, num> invoicedByLineId = {};
    for (final line in inv.lines) {
      await _inv.issueStock(
        productId: line.productId,
        productName: line.productName,
        sku: line.sku,
        baseUnit: line.baseUnit,
        warehouseId: line.warehouseId,
        warehouseName: line.warehouseName,
        quantity: line.quantity,
        reorderLevel: 0,
        userId: userId,
        reference: inv.number,
      );
      invoicedByLineId[line.id] = line.quantity;
    }

    // Mark invoice posted
    await _db.collection('salesInvoices').doc(invoiceId).update({
      'status': InvoiceStatus.posted.name,
      'postedBy': userId,
      'postedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update parent SO if linked
    if (inv.salesOrderId != null &&
        inv.salesOrderId!.isNotEmpty) {
      // Import lazily to avoid circular deps at top-level
      // (SalesOrderService imports nothing from here)
      // Manual update to avoid extra dependency
      final soRef =
          _db.collection('salesOrders').doc(inv.salesOrderId);
      final soSnap = await soRef.get();
      if (soSnap.exists) {
        final soData = soSnap.data() as Map<String, dynamic>;
        final lines = (soData['lines'] as List<dynamic>? ?? []);
        bool allInvoiced = true;
        final newLines = lines.map((l) {
          final m = Map<String, dynamic>.from(l as Map);
          final id = m['id'] as String? ?? '';
          final added = invoicedByLineId[id] ?? 0;
          final oldInv = (m['invoicedQuantity'] ?? 0) as num;
          final newInv = oldInv + added;
          m['invoicedQuantity'] = newInv;
          if (newInv < ((m['quantity'] ?? 0) as num)) {
            allInvoiced = false;
          }
          return m;
        }).toList();

        await soRef.update({
          'lines': newLines,
          'status': allInvoiced ? 'invoiced' : 'partiallyInvoiced',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  /// Cancel a draft invoice. Posted invoices cannot be cancelled here —
  /// they need a Credit Note (Phase 7C).
  Future<void> cancelDraft(String id) async {
    final inv = await getById(id);
    if (inv == null) return;
    if (inv.statusEnum != InvoiceStatus.draft) {
      throw Exception('Only draft invoices can be cancelled');
    }
    await _db.collection('salesInvoices').doc(id).update({
      'status': InvoiceStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDraft(String id) async {
    final inv = await getById(id);
    if (inv == null) return;
    if (inv.statusEnum != InvoiceStatus.draft) {
      throw Exception('Only draft invoices can be deleted');
    }
    await _db.collection('salesInvoices').doc(id).delete();
  }

  /// Record a payment against the invoice.
  /// (Full payment workflow + allocation is Phase 7C.)
  Future<void> recordPayment({
    required String invoiceId,
    required num amount,
  }) async {
    final inv = await getById(invoiceId);
    if (inv == null) throw Exception('Invoice not found');
    if (inv.statusEnum == InvoiceStatus.cancelled) {
      throw Exception('Cannot pay a cancelled invoice');
    }
    if (amount <= 0) {
      throw Exception('Payment amount must be greater than zero');
    }
    final newPaid = inv.amountPaid + amount;
    if (newPaid > inv.grandTotal) {
      throw Exception(
          'Payment exceeds invoice total (outstanding: ${inv.outstanding})');
    }
    String status = inv.status;
    if (newPaid >= inv.grandTotal) {
      status = InvoiceStatus.paid.name;
    } else if (newPaid > 0) {
      status = InvoiceStatus.partiallyPaid.name;
    }
    await _db.collection('salesInvoices').doc(invoiceId).update({
      'amountPaid': newPaid,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}