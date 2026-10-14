import 'package:cloud_firestore/cloud_firestore.dart';

class Warehouse {
  final String id;
  final String name;
  final String code;
  final String location;
  final String? manager;
  final bool active;
  final DateTime? createdAt;

  Warehouse({
    required this.id,
    required this.name,
    required this.code,
    required this.location,
    this.manager,
    required this.active,
    this.createdAt,
  });

  factory Warehouse.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Warehouse(
      id: doc.id,
      name: d['name'] ?? '',
      code: d['code'] ?? '',
      location: d['location'] ?? '',
      manager: d['manager'],
      active: d['active'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'code': code,
        'location': location,
        'manager': manager,
        'active': active,
      };
}

class WarehouseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Warehouse>> watch() {
    return _db
        .collection('warehouses')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(Warehouse.fromDoc).toList());
  }

  Future<void> create(Warehouse w) async {
    // Unique code check
    final existing = await _db
        .collection('warehouses')
        .where('code', isEqualTo: w.code)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Yeh warehouse code pehle se mojood hai: ${w.code}');
    }
    await _db.collection('warehouses').add({
      ...w.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(String id, Warehouse w) async {
    // Unique code check (apne aap ko chhor kar)
    final existing = await _db
        .collection('warehouses')
        .where('code', isEqualTo: w.code)
        .get();
    final conflict = existing.docs.any((d) => d.id != id);
    if (conflict) {
      throw Exception('Yeh code kisi aur warehouse ke paas hai');
    }
    await _db.collection('warehouses').doc(id).update({
      ...w.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    await _db.collection('warehouses').doc(id).delete();
  }
}