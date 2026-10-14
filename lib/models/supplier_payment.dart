import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus {
  posted,
  cancelled,
}

String paymentStatusLabel(PaymentStatus s) {
  switch (s) {
    case PaymentStatus.posted:
      return 'Posted';
    case PaymentStatus.cancelled:
      return 'Cancelled';
  }
}

class PaymentAllocation {
  final String billId;
  final String billNumber;
  final num amount;

  PaymentAllocation({
    required this.billId,
    required this.billNumber,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
        'billId': billId,
        'billNumber': billNumber,
        'amount': amount,
      };

  factory PaymentAllocation.fromMap(Map<String, dynamic> m) =>
      PaymentAllocation(
        billId: m['billId'] ?? '',
        billNumber: m['billNumber'] ?? '',
        amount: (m['amount'] ?? 0) as num,
      );
}

class SupplierPayment {
  final String id;
  final String number;         // PAY-2026-0001
  final String supplierId;
  final String supplierName;
  final String status;
  final String currency;
  final num exchangeRate;
  final num amount;
  final String method;         // cash, bank_transfer, cheque
  final String reference;      // cheque no, txn id
  final List<PaymentAllocation> allocations;
  final String notes;
  final DateTime? paymentDate;
  final DateTime? createdAt;
  final String createdBy;

  SupplierPayment({
    required this.id,
    required this.number,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.currency,
    required this.exchangeRate,
    required this.amount,
    required this.method,
    this.reference = '',
    required this.allocations,
    this.notes = '',
    this.paymentDate,
    this.createdAt,
    this.createdBy = '',
  });

  PaymentStatus get statusEnum => PaymentStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => PaymentStatus.posted,
      );

  num get baseAmount => amount * exchangeRate;

  factory SupplierPayment.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SupplierPayment(
      id: doc.id,
      number: d['number'] ?? '',
      supplierId: d['supplierId'] ?? '',
      supplierName: d['supplierName'] ?? '',
      status: d['status'] ?? 'posted',
      currency: d['currency'] ?? 'PKR',
      exchangeRate: (d['exchangeRate'] ?? 1) as num,
      amount: (d['amount'] ?? 0) as num,
      method: d['method'] ?? 'cash',
      reference: d['reference'] ?? '',
      allocations: (d['allocations'] as List<dynamic>? ?? [])
          .map((e) => PaymentAllocation.fromMap(e as Map<String, dynamic>))
          .toList(),
      notes: d['notes'] ?? '',
      paymentDate: (d['paymentDate'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      createdBy: d['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'number': number,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'status': status,
        'currency': currency,
        'exchangeRate': exchangeRate,
        'amount': amount,
        'method': method,
        'reference': reference,
        'allocations': allocations.map((a) => a.toMap()).toList(),
        'notes': notes,
        'paymentDate':
            paymentDate == null ? null : Timestamp.fromDate(paymentDate!),
        'createdBy': createdBy,
      };
}

const paymentMethods = ['cash', 'bank_transfer', 'cheque', 'online'];