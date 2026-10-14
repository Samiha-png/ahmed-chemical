import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/supplier_payment.dart';
import '../services/supplier_payment_service.dart';

final supplierPaymentServiceProvider =
    Provider<SupplierPaymentService>((ref) => SupplierPaymentService());

final paymentSearchProvider = StateProvider<String>((ref) => '');

final supplierPaymentsStreamProvider =
    StreamProvider<List<SupplierPayment>>((ref) {
  final search = ref.watch(paymentSearchProvider);
  return ref.watch(supplierPaymentServiceProvider).watch(search: search);
});