import 'package:cloud_firestore/cloud_firestore.dart';

class PermissionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns the list of permission keys for a given user.
  Future<Set<String>> permissionsForUser(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) return {};
    final userData = userDoc.data() as Map<String, dynamic>;
    final roleId = userData['role'] as String? ?? '';
    if (roleId.isEmpty) return {};

    // Try new roles collection first
    final roleDoc = await _db.collection('roles').doc(roleId).get();
    if (roleDoc.exists) {
      final rd = roleDoc.data() as Map<String, dynamic>;
      final perms = rd['permissions'] as List<dynamic>? ?? [];
      return perms.map((e) => e.toString()).toSet();
    }

    // Fallback: user has a legacy string role — return empty
    // (or default to read-only). We'll seed roles so this case goes away.
    return {};
  }

  /// Check if a user has a specific permission.
  Future<bool> has(String userId, String permission) async {
    final perms = await permissionsForUser(userId);
    return perms.contains(permission);
  }
}