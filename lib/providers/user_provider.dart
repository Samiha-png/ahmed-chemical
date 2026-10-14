import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/user_service.dart';

final userServiceProvider = Provider<UserService>((ref) => UserService());

final usersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userServiceProvider).watchUsers();
});