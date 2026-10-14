import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/supplier_bill.dart';
import '../services/supplier_bill_service.dart';

final supplierBillServiceProvider =
    Provider<SupplierBillService>((ref) => SupplierBillService());

final billSearchProvider = StateProvider<String>((ref) => '');
final billStatusFilterProvider = StateProvider<String?>((ref) => null);

final supplierBillsStreamProvider =
    StreamProvider<List<SupplierBill>>((ref) {
  final search = ref.watch(billSearchProvider);
  final status = ref.watch(billStatusFilterProvider);
  return ref.watch(supplierBillServiceProvider).watch(
        search: search,
        status: status,
      );
});