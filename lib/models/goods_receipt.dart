import 'package:cloud_firestore/cloud_firestore.dart';

enum GRNStatus {
  draft,
  posted,
  cancelled,
}

String grnStatusLabel(GRNStatus s) {
  switch (s) {
    case GRNStatus.draft:
      return 'Draft';
    case GRNStatus.posted:
      return 'Posted';
    case GRNStatus.cancelled:
      return 'Cancelled';
  }
}

class GRNLine {
  final String id;
  final String poLineId;
  final String productId;
  final String productName;
  final String sku;
  final String baseUnit;
  final num quantity;      // received in this GRN
  final num unitCost;      // actual cost at receiving
  final num orderedQty;    // total ordered on PO line

  GRNLine({
    required this.id,
    required this.poLineId,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.baseUnit,
    required this.quantity,
    required this.unitCost,
    required this.orderedQty,
  });

  num get totalValue => quantity * unitCost;

  Map<String, dynamic> toMap() => {
        'id': id,
        'poLineId': poLineId,
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'baseUnit': baseUnit,
        'quantity': quantity,
        'unitCost': unitCost,
        'orderedQty': orderedQty,
      };

  factory GRNLine.fromMap(Map<String, dynamic> m) => GRNLine(
        id: m['id'] ?? '',
        poLineId: m['poLineId'] ?? '',
        productId: m['productId'] ?? '',
        productName: m['productName'] ?? '',
        sku: m['sku'] ?? '',
        baseUnit: m['baseUnit'] ?? 'kg',
        quantity: (m['quantity'] ?? 0) as num,
        unitCost: (m['unitCost'] ?? 0) as num,
        orderedQty: (m['orderedQty'] ?? 0) as num,
      );
}

class GoodsReceipt {
  final String id;
  final String number;         // GRN-2026-0001
  final String poId;
  final String poNumber;
  final String supplierId;
  final String supplierName;
  final String warehouseId;
  final String warehouseName;
  final String status;
  final List<GRNLine> lines;
  final String notes;
  final DateTime? receivedDate;
  final DateTime? createdAt;
  final DateTime? postedAt;
  final String createdBy;
  final String postedBy;

  GoodsReceipt({
    required this.id,
    required this.number,
    required this.poId,
    required this.poNumber,
    required this.supplierId,
    required this.supplierName,
    required this.warehouseId,
    required this.warehouseName,
    required this.status,
    required this.lines,
    this.notes = '',
    this.receivedDate,
    this.createdAt,
    this.postedAt,
    this.createdBy = '',
    this.postedBy = '',
  });

  GRNStatus get statusEnum => GRNStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => GRNStatus.draft,
      );

  num get totalValue =>
      lines.fold<num>(0, (a, l) => a + l.totalValue);

  factory GoodsReceipt.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GoodsReceipt(
      id: doc.id,
      number: d['number'] ?? '',
      poId: d['poId'] ?? '',
      poNumber: d['poNumber'] ?? '',
      supplierId: d['supplierId'] ?? '',
      supplierName: d['supplierName'] ?? '',
      warehouseId: d['warehouseId'] ?? '',
      warehouseName: d['warehouseName'] ?? '',
      status: d['status'] ?? 'draft',
      lines: (d['lines'] as List<dynamic>? ?? [])
          .map((e) => GRNLine.fromMap(e as Map<String, dynamic>))
          .toList(),
      notes: d['notes'] ?? '',
      receivedDate: (d['receivedDate'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      postedAt: (d['postedAt'] as Timestamp?)?.toDate(),
      createdBy: d['createdBy'] ?? '',
      postedBy: d['postedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'number': number,
        'poId': poId,
        'poNumber': poNumber,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'warehouseId': warehouseId,
        'warehouseName': warehouseName,
        'status': status,
        'lines': lines.map((l) => l.toMap()).toList(),
        'notes': notes,
        'receivedDate': receivedDate == null
            ? null
            : Timestamp.fromDate(receivedDate!),
        'createdBy': createdBy,
        'postedBy': postedBy,
      };
}