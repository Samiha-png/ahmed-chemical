import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String code;
  final String name;
  final String contactPerson;
  final String email;
  final String phone;
  final String billingAddress;
  final String shippingAddress;
  final String country;
  final String currency;
  final int paymentTermsDays;
  final num creditLimit;
  final num openingBalance;
  final String notes;
  final bool active;
  final DateTime? createdAt;

  Customer({
    required this.id,
    required this.code,
    required this.name,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.billingAddress,
    required this.shippingAddress,
    required this.country,
    required this.currency,
    required this.paymentTermsDays,
    required this.creditLimit,
    required this.openingBalance,
    required this.notes,
    required this.active,
    this.createdAt,
  });

  factory Customer.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      code: d['code'] ?? '',
      name: d['name'] ?? '',
      contactPerson: d['contactPerson'] ?? '',
      email: d['email'] ?? '',
      phone: d['phone'] ?? '',
      billingAddress: d['billingAddress'] ?? '',
      shippingAddress: d['shippingAddress'] ?? '',
      country: d['country'] ?? 'Pakistan',
      currency: d['currency'] ?? 'PKR',
      paymentTermsDays: (d['paymentTermsDays'] ?? 30) as int,
      creditLimit: (d['creditLimit'] ?? 0) as num,
      openingBalance: (d['openingBalance'] ?? 0) as num,
      notes: d['notes'] ?? '',
      active: d['active'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'contactPerson': contactPerson,
        'email': email,
        'phone': phone,
        'billingAddress': billingAddress,
        'shippingAddress': shippingAddress,
        'country': country,
        'currency': currency,
        'paymentTermsDays': paymentTermsDays,
        'creditLimit': creditLimit,
        'openingBalance': openingBalance,
        'notes': notes,
        'active': active,
      };
}

class CustomerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Customer>> watch({String? search}) {
    return _db
        .collection('customers')
        .orderBy('name')
        .snapshots()
        .map((s) {
      var list = s.docs.map(Customer.fromDoc).toList();
      if (search != null && search.trim().isNotEmpty) {
        final q = search.toLowerCase();
        list = list
            .where((x) =>
                x.name.toLowerCase().contains(q) ||
                x.code.toLowerCase().contains(q) ||
                x.email.toLowerCase().contains(q))
            .toList();
      }
      return list;
    });
  }

  Future<Customer?> getById(String id) async {
    final doc = await _db.collection('customers').doc(id).get();
    if (!doc.exists) return null;
    return Customer.fromDoc(doc);
  }

  Future<String> create(Customer c) async {
    final existing = await _db
        .collection('customers')
        .where('code', isEqualTo: c.code)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Customer code already exists: ${c.code}');
    }
    final ref = await _db.collection('customers').add({
      ...c.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String id, Customer c) async {
    final existing = await _db
        .collection('customers')
        .where('code', isEqualTo: c.code)
        .get();
    final conflict = existing.docs.any((d) => d.id != id);
    if (conflict) {
      throw Exception('Customer code belongs to another customer');
    }
    await _db.collection('customers').doc(id).update({
      ...c.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    await _db.collection('customers').doc(id).delete();
  }
}