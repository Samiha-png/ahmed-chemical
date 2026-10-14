import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/sales_invoice.dart';
import '../services/sales_invoice_service.dart';

final salesInvoiceServiceProvider =
    Provider<SalesInvoiceService>((ref) => SalesInvoiceService());

final invoiceSearchProvider = StateProvider<String>((ref) => '');
final invoiceStatusFilterProvider = StateProvider<String?>((ref) => null);

final salesInvoicesStreamProvider =
    StreamProvider<List<SalesInvoice>>((ref) {
  final search = ref.watch(invoiceSearchProvider);
  final status = ref.watch(invoiceStatusFilterProvider);
  return ref.watch(salesInvoiceServiceProvider).watch(
        search: search,
        status: status,
      );
});