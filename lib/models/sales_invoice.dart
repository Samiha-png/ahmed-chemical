import 'package:cloud_firestore/cloud_firestore.dart';

enum InvoiceStatus {
  draft,
  posted,
  partiallyPaid,
  paid,
  cancelled,
}

String invoiceStatusLabel(InvoiceStatus s) {
  switch (s) {
    case InvoiceStatus.draft:
      return 'Draft';
    case InvoiceStatus.posted:
      return 'Posted';
    case InvoiceStatus.partiallyPaid:
      return 'Partially Paid';
    case InvoiceStatus.paid:
      return 'Paid';
    case InvoiceStatus.cancelled:
      return 'Cancelled';
  }
}

class InvLine {
  final String id;
  final String productId;
  final String productName;
  final String sku;
  final String baseUnit;
  final String warehouseId;
  final String warehouseName;
  final num quantity;
  final num unitPrice;
  final num discountPercent;
  final num taxPercent;
  final num unitCost;

  InvLine({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.baseUnit,
    required this.warehouseId,
    required this.warehouseName,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    this.taxPercent = 0,
    this.unitCost = 0,
  });

  num get gross => quantity * unitPrice;
  num get discount => gross * discountPercent / 100;
  num get subtotal => gross - discount;
  num get tax => subtotal * taxPercent / 100;
  num get lineTotal => subtotal + tax;
  num get lineCost => quantity * unitCost;
  num get lineProfit => (subtotal) - lineCost;

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'baseUnit': baseUnit,
        'warehouseId': warehouseId,
        'warehouseName': warehouseName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountPercent': discountPercent,
        'taxPercent': taxPercent,
        'unitCost': unitCost,
      };

  factory InvLine.fromMap(Map<String, dynamic> m) => InvLine(
        id: m['id'] ?? '',
        productId: m['productId'] ?? '',
        productName: m['productName'] ?? '',
        sku: m['sku'] ?? '',
        baseUnit: m['baseUnit'] ?? 'kg',
        warehouseId: m['warehouseId'] ?? '',
        warehouseName: m['warehouseName'] ?? '',
        quantity: (m['quantity'] ?? 0) as num,
        unitPrice: (m['unitPrice'] ?? 0) as num,
        discountPercent: (m['discountPercent'] ?? 0) as num,
        taxPercent: (m['taxPercent'] ?? 0) as num,
        unitCost: (m['unitCost'] ?? 0) as num,
      );
}

class SalesInvoice {
  final String id;
  final String number;
  final String? salesOrderId;
  final String customerId;
  final String customerName;
  final String status;
  final String currency;
  final num exchangeRate;
  final List<InvLine> lines;
  final num freight;
  final num otherCharges;
  final num amountPaid;
  final String notes;
  final DateTime? invoiceDate;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? postedAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String postedBy;

  SalesInvoice({
    required this.id,
    required this.number,
    this.salesOrderId,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.currency,
    required this.exchangeRate,
    required this.lines,
    this.freight = 0,
    this.otherCharges = 0,
    this.amountPaid = 0,
    this.notes = '',
    this.invoiceDate,
    this.dueDate,
    this.createdAt,
    this.postedAt,
    this.updatedAt,
    this.createdBy = '',
    this.postedBy = '',
  });

  InvoiceStatus get statusEnum => InvoiceStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => InvoiceStatus.draft,
      );

  num get subtotal => lines.fold<num>(0, (a, l) => a + l.subtotal);
  num get taxTotal => lines.fold<num>(0, (a, l) => a + l.tax);
  num get grandTotal => subtotal + taxTotal + freight + otherCharges;
  num get baseTotal => grandTotal * exchangeRate;
  num get outstanding => grandTotal - amountPaid;
  num get cogs => lines.fold<num>(0, (a, l) => a + l.lineCost);
  num get grossProfit => subtotal - cogs;

  factory SalesInvoice.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SalesInvoice(
      id: doc.id,
      number: d['number'] ?? '',
      salesOrderId: d['salesOrderId'],
      customerId: d['customerId'] ?? '',
      customerName: d['customerName'] ?? '',
      status: d['status'] ?? 'draft',
      currency: d['currency'] ?? 'PKR',
      exchangeRate: (d['exchangeRate'] ?? 1) as num,
      lines: (d['lines'] as List<dynamic>? ?? [])
          .map((e) => InvLine.fromMap(e as Map<String, dynamic>))
          .toList(),
      freight: (d['freight'] ?? 0) as num,
      otherCharges: (d['otherCharges'] ?? 0) as num,
      amountPaid: (d['amountPaid'] ?? 0) as num,
      notes: d['notes'] ?? '',
      invoiceDate: (d['invoiceDate'] as Timestamp?)?.toDate(),
      dueDate: (d['dueDate'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      postedAt: (d['postedAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: d['createdBy'] ?? '',
      postedBy: d['postedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'number': number,
        'salesOrderId': salesOrderId,
        'customerId': customerId,
        'customerName': customerName,
        'status': status,
        'currency': currency,
        'exchangeRate': exchangeRate,
        'lines': lines.map((l) => l.toMap()).toList(),
        'freight': freight,
        'otherCharges': otherCharges,
        'amountPaid': amountPaid,
        'notes': notes,
        'invoiceDate': invoiceDate == null
            ? null
            : Timestamp.fromDate(invoiceDate!),
        'dueDate':
            dueDate == null ? null : Timestamp.fromDate(dueDate!),
        'createdBy': createdBy,
        'postedBy': postedBy,
      };
}