import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/purchase_order.dart';
import '../services/purchase_order_service.dart';

final purchaseOrderServiceProvider =
    Provider<PurchaseOrderService>((ref) => PurchaseOrderService());

final poSearchProvider = StateProvider<String>((ref) => '');
final poStatusFilterProvider = StateProvider<String?>((ref) => null);

final purchaseOrdersStreamProvider = StreamProvider<List<PurchaseOrder>>((ref) {
  final search = ref.watch(poSearchProvider);
  final status = ref.watch(poStatusFilterProvider);
  return ref.watch(purchaseOrderServiceProvider).watch(
        search: search,
        status: status,
      );
});