import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/role.dart';
import '../services/role_service.dart';

final roleServiceProvider =
    Provider<RoleService>((ref) => RoleService());

final rolesStreamProvider = StreamProvider<List<Role>>((ref) {
  return ref.watch(roleServiceProvider).watch();
});

/// The currently signed-in user's role (as a full Role object).
final currentUserRoleProvider = Provider<Role?>((ref) {
  // This will be populated by AuthService; falls back to null.
  // See permission_checker below for actual usage.
  return null;
});