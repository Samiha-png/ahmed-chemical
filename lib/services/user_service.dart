import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String role;
  final bool active;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.active,
    this.createdAt,
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: d['email'] ?? '',
      fullName: d['fullName'] ?? '',
      role: d['role'] ?? 'read_only',
      active: d['active'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AppUser>> watchUsers() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AppUser.fromDoc).toList());
  }

  Future<void> updateRole(String uid, String role) async {
    await _db.collection('users').doc(uid).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleActive(String uid, bool active) async {
    await _db.collection('users').doc(uid).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile(String uid, String fullName) async {
    await _db.collection('users').doc(uid).update({
      'fullName': fullName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

const roleLabels = {
  'super_admin': 'Super Admin',
  'director': 'Director / Management',
  'finance_manager': 'Finance Manager',
  'accountant': 'Accountant',
  'inventory_manager': 'Inventory Manager',
  'purchase_officer': 'Purchase Officer',
  'sales_officer': 'Sales Officer',
  'read_only': 'Read-Only Auditor',
};