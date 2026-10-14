import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/inventory_service.dart';

final inventoryServiceProvider =
    Provider<InventoryService>((ref) => InventoryService());

final inventorySearchProvider = StateProvider<String>((ref) => '');

final inventoryWarehouseFilterProvider =
    StateProvider<String?>((ref) => null);

final stockBalancesProvider = StreamProvider<List<StockBalance>>((ref) {
  final search = ref.watch(inventorySearchProvider);
  final wh = ref.watch(inventoryWarehouseFilterProvider);
  return ref.watch(inventoryServiceProvider).watchBalances(
        search: search,
        warehouseId: wh,
      );
});

final lowStockProvider = StreamProvider<List<StockBalance>>((ref) {
  final all = ref.watch(stockBalancesProvider);
  return all.when(
    data: (list) async* {
      yield list.where((b) => b.isLowStock).toList();
    },
    loading: () => const Stream.empty(),
    error: (e, _) => Stream.error(e),
  );
});

final movementsProvider = StreamProvider.family<List<InventoryMovement>,
    ({String? productId, String? warehouseId})>((ref, args) {
  return ref.watch(inventoryServiceProvider).watchMovements(
        productId: args.productId,
        warehouseId: args.warehouseId,
      );
});