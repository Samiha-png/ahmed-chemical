import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/goods_receipt.dart';
import '../services/goods_receipt_service.dart';

final goodsReceiptServiceProvider =
    Provider<GoodsReceiptService>((ref) => GoodsReceiptService());

final grnSearchProvider = StateProvider<String>((ref) => '');
final grnStatusFilterProvider = StateProvider<String?>((ref) => null);

final goodsReceiptsStreamProvider =
    StreamProvider<List<GoodsReceipt>>((ref) {
  final search = ref.watch(grnSearchProvider);
  final status = ref.watch(grnStatusFilterProvider);
  return ref.watch(goodsReceiptServiceProvider).watch(
        search: search,
        status: status,
      );
});