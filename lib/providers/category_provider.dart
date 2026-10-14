import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/category_service.dart';

final categoryServiceProvider =
    Provider<CategoryService>((ref) => CategoryService());

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryServiceProvider).watch();
});