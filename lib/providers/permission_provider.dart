import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import '../services/permission_service.dart';

final permissionServiceProvider =
    Provider<PermissionService>((ref) => PermissionService());

/// Async set of permissions for the current user.
final currentPermissionsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return {};
  return ref
      .read(permissionServiceProvider)
      .permissionsForUser(user.uid);
});

/// Synchronous helper — returns true if the given permission is present.
/// Use inside UI: `if (ref.watch(hasPermissionProvider('products.create')))`
final hasPermissionProvider =
    Provider.family<bool, String>((ref, permission) {
  final perms = ref.watch(currentPermissionsProvider);
  return perms.value?.contains(permission) ?? false;
});