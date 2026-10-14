import 'package:cloud_firestore/cloud_firestore.dart';

/// Status lifecycle of a Purchase Order.
enum POStatus {
  draft,             // Being prepared
  approved,          // Approved by management
  partiallyReceived, // Some items received via GRN
  received,          // Fully received
  cancelled,         // Cancelled
  closed,            // Manually closed
}

String poStatusLabel(POStatus s) {
  switch (s) {
    case POStatus.draft:
      return 'Draft';
    case POStatus.approved:
      return 'Approved';
    case POStatus.partiallyReceived:
      return 'Partially Received';
    case POStatus.received:
      return 'Received';
    case POStatus.cancelled:
      return 'Cancelled';
    case POStatus.closed:
      return 'Closed';
  }
}

class POLine {
  final String id;              // Unique line id
  final String productId;
  final String productName;
  final String sku;
  final String baseUnit;
  final num quantity;
  final num unitPrice;
  final num discountPercent;    // 0-100
  final num taxPercent;         // 0-100
  final num receivedQuantity;   // Filled by GRN later

  POLine({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.baseUnit,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    this.taxPercent = 0,
    this.receivedQuantity = 0,
  });

  num get gross => quantity * unitPrice;
  num get discount => gross * discountPercent / 100;
  num get subtotal => gross - discount;
  num get tax => subtotal * taxPercent / 100;
  num get lineTotal => subtotal + tax;

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'baseUnit': baseUnit,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountPercent': discountPercent,
        'taxPercent': taxPercent,
        'receivedQuantity': receivedQuantity,
      };

  factory POLine.fromMap(Map<String, dynamic> m) => POLine(
        id: m['id'] ?? '',
        productId: m['productId'] ?? '',
        productName: m['productName'] ?? '',
        sku: m['sku'] ?? '',
        baseUnit: m['baseUnit'] ?? 'kg',
        quantity: (m['quantity'] ?? 0) as num,
        unitPrice: (m['unitPrice'] ?? 0) as num,
        discountPercent: (m['discountPercent'] ?? 0) as num,
        taxPercent: (m['taxPercent'] ?? 0) as num,
        receivedQuantity: (m['receivedQuantity'] ?? 0) as num,
      );
}

class PurchaseOrder {
  final String id;
  final String number;         // PO-2026-0001
  final String supplierId;
  final String supplierName;
  final String status;         // POStatus.name
  final String currency;       // PKR, USD, ...
  final num exchangeRate;      // to base (PKR)
  final List<POLine> lines;
  final num freight;           // Landed cost addition
  final num otherCharges;
  final String notes;
  final DateTime? expectedDelivery;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String approvedBy;

  PurchaseOrder({
    required this.id,
    required this.number,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.currency,
    required this.exchangeRate,
    required this.lines,
    this.freight = 0,
    this.otherCharges = 0,
    this.notes = '',
    this.expectedDelivery,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.approvedBy = '',
  });

  POStatus get statusEnum => POStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => POStatus.draft,
      );

  num get subtotal => lines.fold<num>(0, (a, l) => a + l.subtotal);
  num get taxTotal => lines.fold<num>(0, (a, l) => a + l.tax);
  num get grandTotal => subtotal + taxTotal + freight + otherCharges;
  num get baseTotal => grandTotal * exchangeRate;

  factory PurchaseOrder.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PurchaseOrder(
      id: doc.id,
      number: d['number'] ?? '',
      supplierId: d['supplierId'] ?? '',
      supplierName: d['supplierName'] ?? '',
      status: d['status'] ?? 'draft',
      currency: d['currency'] ?? 'PKR',
      exchangeRate: (d['exchangeRate'] ?? 1) as num,
      lines: (d['lines'] as List<dynamic>? ?? [])
          .map((e) => POLine.fromMap(e as Map<String, dynamic>))
          .toList(),
      freight: (d['freight'] ?? 0) as num,
      otherCharges: (d['otherCharges'] ?? 0) as num,
      notes: d['notes'] ?? '',
      expectedDelivery: (d['expectedDelivery'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: d['createdBy'] ?? '',
      approvedBy: d['approvedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'number': number,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'status': status,
        'currency': currency,
        'exchangeRate': exchangeRate,
        'lines': lines.map((l) => l.toMap()).toList(),
        'freight': freight,
        'otherCharges': otherCharges,
        'notes': notes,
        'expectedDelivery': expectedDelivery == null
            ? null
            : Timestamp.fromDate(expectedDelivery!),
        'createdBy': createdBy,
        'approvedBy': approvedBy,
      };
}