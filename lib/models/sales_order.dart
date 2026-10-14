import 'package:cloud_firestore/cloud_firestore.dart';

enum SOStatus {
  draft,
  confirmed,
  partiallyInvoiced,
  invoiced,
  cancelled,
  closed,
}

String soStatusLabel(SOStatus s) {
  switch (s) {
    case SOStatus.draft:
      return 'Draft';
    case SOStatus.confirmed:
      return 'Confirmed';
    case SOStatus.partiallyInvoiced:
      return 'Partially Invoiced';
    case SOStatus.invoiced:
      return 'Invoiced';
    case SOStatus.cancelled:
      return 'Cancelled';
    case SOStatus.closed:
      return 'Closed';
  }
}

class SOLine {
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
  final num invoicedQuantity;

  SOLine({
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
    this.invoicedQuantity = 0,
  });

  num get gross => quantity * unitPrice;
  num get discount => gross * discountPercent / 100;
  num get subtotal => gross - discount;
  num get tax => subtotal * taxPercent / 100;
  num get lineTotal => subtotal + tax;

  num get remainingToInvoice => quantity - invoicedQuantity;
  bool get isFullyInvoiced => invoicedQuantity >= quantity;

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
        'invoicedQuantity': invoicedQuantity,
      };

  factory SOLine.fromMap(Map<String, dynamic> m) => SOLine(
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
        invoicedQuantity: (m['invoicedQuantity'] ?? 0) as num,
      );
}

class SalesOrder {
  final String id;
  final String number;
  final String customerId;
  final String customerName;
  final String status;
  final String currency;
  final num exchangeRate;
  final List<SOLine> lines;
  final num freight;
  final num otherCharges;
  final String notes;
  final DateTime? expectedDelivery;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String confirmedBy;

  SalesOrder({
    required this.id,
    required this.number,
    required this.customerId,
    required this.customerName,
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
    this.confirmedBy = '',
  });

  SOStatus get statusEnum => SOStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => SOStatus.draft,
      );

  num get subtotal => lines.fold<num>(0, (a, l) => a + l.subtotal);
  num get taxTotal => lines.fold<num>(0, (a, l) => a + l.tax);
  num get grandTotal => subtotal + taxTotal + freight + otherCharges;
  num get baseTotal => grandTotal * exchangeRate;

  factory SalesOrder.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SalesOrder(
      id: doc.id,
      number: d['number'] ?? '',
      customerId: d['customerId'] ?? '',
      customerName: d['customerName'] ?? '',
      status: d['status'] ?? 'draft',
      currency: d['currency'] ?? 'PKR',
      exchangeRate: (d['exchangeRate'] ?? 1) as num,
      lines: (d['lines'] as List<dynamic>? ?? [])
          .map((e) => SOLine.fromMap(e as Map<String, dynamic>))
          .toList(),
      freight: (d['freight'] ?? 0) as num,
      otherCharges: (d['otherCharges'] ?? 0) as num,
      notes: d['notes'] ?? '',
      expectedDelivery: (d['expectedDelivery'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: d['createdBy'] ?? '',
      confirmedBy: d['confirmedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'number': number,
        'customerId': customerId,
        'customerName': customerName,
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
        'confirmedBy': confirmedBy,
      };
}