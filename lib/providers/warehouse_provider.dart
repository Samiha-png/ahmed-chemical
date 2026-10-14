import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/warehouse_service.dart';

final warehouseServiceProvider =
    Provider<WarehouseService>((ref) => WarehouseService());

final warehousesStreamProvider = StreamProvider<List<Warehouse>>((ref) {
  return ref.watch(warehouseServiceProvider).watch();
});