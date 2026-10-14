import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/sales_order.dart';
import '../services/sales_order_service.dart';

final salesOrderServiceProvider =
    Provider<SalesOrderService>((ref) => SalesOrderService());

final soSearchProvider = StateProvider<String>((ref) => '');
final soStatusFilterProvider = StateProvider<String?>((ref) => null);

final salesOrdersStreamProvider =
    StreamProvider<List<SalesOrder>>((ref) {
  final search = ref.watch(soSearchProvider);
  final status = ref.watch(soStatusFilterProvider);
  return ref.watch(salesOrderServiceProvider).watch(
        search: search,
        status: status,
      );
});