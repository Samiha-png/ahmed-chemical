import 'package:cloud_firestore/cloud_firestore.dart';

enum BillStatus {
  draft,
  posted,
  partiallyPaid,
  paid,
  cancelled,
}

String billStatusLabel(BillStatus s) {
  switch (s) {
    case BillStatus.draft:
      return 'Draft';
    case BillStatus.posted:
      return 'Posted';
    case BillStatus.partiallyPaid:
      return 'Partially Paid';
    case BillStatus.paid:
      return 'Paid';
    case BillStatus.cancelled:
      return 'Cancelled';
  }
}

class BillLine {
  final String id;
  final String productId;
  final String productName;
  final String sku;
  final String baseUnit;
  final num quantity;
  final num unitPrice;
  final num discountPercent;
  final num taxPercent;

  BillLine({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.baseUnit,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    this.taxPercent = 0,
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
      };

  factory BillLine.fromMap(Map<String, dynamic> m) => BillLine(
        id: m['id'] ?? '',
        productId: m['productId'] ?? '',
        productName: m['productName'] ?? '',
        sku: m['sku'] ?? '',
        baseUnit: m['baseUnit'] ?? 'kg',
        quantity: (m['quantity'] ?? 0) as num,
        unitPrice: (m['unitPrice'] ?? 0) as num,
        discountPercent: (m['discountPercent'] ?? 0) as num,
        taxPercent: (m['taxPercent'] ?? 0) as num,
      );
}

class SupplierBill {
  final String id;
  final String number;         // BILL-2026-0001
  final String? poId;
  final String? grnId;
  final String supplierId;
  final String supplierName;
  final String supplierBillNumber; // Supplier's own bill number
  final String status;
  final String currency;
  final num exchangeRate;
  final List<BillLine> lines;
  final num freight;
  final num otherCharges;
  final num amountPaid;
  final String notes;
  final DateTime? billDate;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? postedAt;
  final String createdBy;
  final String postedBy;

  SupplierBill({
    required this.id,
    required this.number,
    this.poId,
    this.grnId,
    required this.supplierId,
    required this.supplierName,
    this.supplierBillNumber = '',
    required this.status,
    required this.currency,
    required this.exchangeRate,
    required this.lines,
    this.freight = 0,
    this.otherCharges = 0,
    this.amountPaid = 0,
    this.notes = '',
    this.billDate,
    this.dueDate,
    this.createdAt,
    this.postedAt,
    this.createdBy = '',
    this.postedBy = '',
  });

  BillStatus get statusEnum => BillStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => BillStatus.draft,
      );

  num get subtotal => lines.fold<num>(0, (a, l) => a + l.subtotal);
  num get taxTotal => lines.fold<num>(0, (a, l) => a + l.tax);
  num get grandTotal => subtotal + taxTotal + freight + otherCharges;
  num get baseTotal => grandTotal * exchangeRate;
  num get outstanding => grandTotal - amountPaid;

  factory SupplierBill.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SupplierBill(
      id: doc.id,
      number: d['number'] ?? '',
      poId: d['poId'],
      grnId: d['grnId'],
      supplierId: d['supplierId'] ?? '',
      supplierName: d['supplierName'] ?? '',
      supplierBillNumber: d['supplierBillNumber'] ?? '',
      status: d['status'] ?? 'draft',
      currency: d['currency'] ?? 'PKR',
      exchangeRate: (d['exchangeRate'] ?? 1) as num,
      lines: (d['lines'] as List<dynamic>? ?? [])
          .map((e) => BillLine.fromMap(e as Map<String, dynamic>))
          .toList(),
      freight: (d['freight'] ?? 0) as num,
      otherCharges: (d['otherCharges'] ?? 0) as num,
      amountPaid: (d['amountPaid'] ?? 0) as num,
      notes: d['notes'] ?? '',
      billDate: (d['billDate'] as Timestamp?)?.toDate(),
      dueDate: (d['dueDate'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      postedAt: (d['postedAt'] as Timestamp?)?.toDate(),
      createdBy: d['createdBy'] ?? '',
      postedBy: d['postedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'number': number,
        'poId': poId,
        'grnId': grnId,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'supplierBillNumber': supplierBillNumber,
        'status': status,
        'currency': currency,
        'exchangeRate': exchangeRate,
        'lines': lines.map((l) => l.toMap()).toList(),
        'freight': freight,
        'otherCharges': otherCharges,
        'amountPaid': amountPaid,
        'notes': notes,
        'billDate': billDate == null ? null : Timestamp.fromDate(billDate!),
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
        'createdBy': createdBy,
        'postedBy': postedBy,
      };
}