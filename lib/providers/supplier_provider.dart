import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/supplier_service.dart';

final supplierServiceProvider =
    Provider<SupplierService>((ref) => SupplierService());

final supplierSearchProvider = StateProvider<String>((ref) => '');

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  final search = ref.watch(supplierSearchProvider);
  return ref.watch(supplierServiceProvider).watch(search: search);
});