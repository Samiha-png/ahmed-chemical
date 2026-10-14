import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/role.dart';

class RoleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Role>> watch() {
    return _db
        .collection('roles')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(Role.fromDoc).toList());
  }

  Future<Role?> getById(String id) async {
    final doc = await _db.collection('roles').doc(id).get();
    if (!doc.exists) return null;
    return Role.fromDoc(doc);
  }

  /// Seed default roles if collection is empty.
  Future<bool> seedDefaultRoles() async {
    final existing = await _db.collection('roles').limit(1).get();
    if (existing.docs.isNotEmpty) return false;

    final batch = _db.batch();
    for (final r in DefaultRoles.seed()) {
      final ref = _db.collection('roles').doc(r.id);
      batch.set(ref, {
        ...r.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return true;
  }

  Future<String> create(Role role) async {
    if (role.name.trim().isEmpty) {
      throw Exception('Role name is required');
    }
    final ref = await _db.collection('roles').add({
      ...role.toMap(),
      'isSystem': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String id, Role role) async {
    final existing = await getById(id);
    if (existing == null) throw Exception('Role not found');
    if (existing.isSystem) {
      throw Exception('System roles cannot be modified');
    }
    await _db.collection('roles').doc(id).update({
      ...role.toMap(),
      'isSystem': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    final role = await getById(id);
    if (role == null) return;
    if (role.isSystem) {
      throw Exception('System roles cannot be deleted');
    }
    // Check if any user has this role
    final usersWithRole = await _db
        .collection('users')
        .where('role', isEqualTo: id)
        .limit(1)
        .get();
    if (usersWithRole.docs.isNotEmpty) {
      throw Exception(
          'Cannot delete role — some users are still assigned to it');
    }
    await _db.collection('roles').doc(id).delete();
  }
}