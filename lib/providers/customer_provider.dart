import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/customer_service.dart';

final customerServiceProvider =
    Provider<CustomerService>((ref) => CustomerService());

final customerSearchProvider = StateProvider<String>((ref) => '');

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  final search = ref.watch(customerSearchProvider);
  return ref.watch(customerServiceProvider).watch(search: search);
});