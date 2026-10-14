import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  final String id;
  final String code;
  final String name;
  final String contactPerson;
  final String email;
  final String phone;
  final String address;
  final String country;
  final String currency;
  final int paymentTermsDays;
  final num creditLimit;
  final num openingBalance;
  final String notes;
  final bool active;
  final DateTime? createdAt;

  Supplier({
    required this.id,
    required this.code,
    required this.name,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.address,
    required this.country,
    required this.currency,
    required this.paymentTermsDays,
    required this.creditLimit,
    required this.openingBalance,
    required this.notes,
    required this.active,
    this.createdAt,
  });

  factory Supplier.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Supplier(
      id: doc.id,
      code: d['code'] ?? '',
      name: d['name'] ?? '',
      contactPerson: d['contactPerson'] ?? '',
      email: d['email'] ?? '',
      phone: d['phone'] ?? '',
      address: d['address'] ?? '',
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
        'address': address,
        'country': country,
        'currency': currency,
        'paymentTermsDays': paymentTermsDays,
        'creditLimit': creditLimit,
        'openingBalance': openingBalance,
        'notes': notes,
        'active': active,
      };
}

class SupplierService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Supplier>> watch({String? search}) {
    return _db
        .collection('suppliers')
        .orderBy('name')
        .snapshots()
        .map((s) {
      var list = s.docs.map(Supplier.fromDoc).toList();
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

  Future<Supplier?> getById(String id) async {
    final doc = await _db.collection('suppliers').doc(id).get();
    if (!doc.exists) return null;
    return Supplier.fromDoc(doc);
  }

  Future<String> create(Supplier s) async {
    final existing = await _db
        .collection('suppliers')
        .where('code', isEqualTo: s.code)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Supplier code already exists: ${s.code}');
    }
    final ref = await _db.collection('suppliers').add({
      ...s.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String id, Supplier s) async {
    final existing = await _db
        .collection('suppliers')
        .where('code', isEqualTo: s.code)
        .get();
    final conflict = existing.docs.any((d) => d.id != id);
    if (conflict) {
      throw Exception('Supplier code belongs to another supplier');
    }
    await _db.collection('suppliers').doc(id).update({
      ...s.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    await _db.collection('suppliers').doc(id).delete();
  }
}

const countries = [
  'Pakistan', 'UAE', 'China', 'India', 'Germany', 'USA', 'UK', 'Saudi Arabia', 'Other',
];

const supplierCurrencies = ['PKR', 'USD', 'EUR', 'GBP', 'AED', 'CNY'];