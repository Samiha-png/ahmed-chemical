import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/product_service.dart';

final productServiceProvider =
    Provider<ProductService>((ref) => ProductService());

final productSearchProvider = StateProvider<String>((ref) => '');

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final search = ref.watch(productSearchProvider);
  return ref.watch(productServiceProvider).watch(search: search);
});