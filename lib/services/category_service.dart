import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;
  final String? parentId; // subcategory ke liye
  final String description;
  final bool active;
  final DateTime? createdAt;

  Category({
    required this.id,
    required this.name,
    this.parentId,
    required this.description,
    required this.active,
    this.createdAt,
  });

  factory Category.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      name: d['name'] ?? '',
      parentId: d['parentId'],
      description: d['description'] ?? '',
      active: d['active'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'parentId': parentId,
        'description': description,
        'active': active,
      };
}

class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Category>> watch() {
    return _db
        .collection('categories')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(Category.fromDoc).toList());
  }

  Future<void> create(Category c) async {
    await _db.collection('categories').add({
      ...c.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(String id, Category c) async {
    await _db.collection('categories').doc(id).update({
      ...c.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    await _db.collection('categories').doc(id).delete();
  }
}