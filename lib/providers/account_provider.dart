import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/account.dart';
import '../services/account_service.dart';

final accountServiceProvider =
    Provider<AccountService>((ref) => AccountService());

final accountTypeFilterProvider = StateProvider<AccountType?>((ref) => null);

final chartOfAccountsProvider = StreamProvider<List<Account>>((ref) {
  final type = ref.watch(accountTypeFilterProvider);
  return ref.watch(accountServiceProvider).watch(type: type);
});