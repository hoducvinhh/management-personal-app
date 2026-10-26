import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

class CategoriesNotifier extends AsyncNotifier<List<CategoryModel>> {
  @override
  Future<List<CategoryModel>> build() async {
    final repo = ref.watch(categoryRepositoryProvider);
    return repo.getCategories();
  }

  Future<void> addCategory(CategoryModel category) async {
    final repo = ref.read(categoryRepositoryProvider);
    await repo.insertCategory(category);
    ref.invalidateSelf();
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<CategoryModel>>(
        CategoriesNotifier.new);

final expenseCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final asyncCategories = ref.watch(categoriesProvider);
  return asyncCategories.maybeWhen(
    data: (cats) => cats.where((c) => c.isExpense).toList(),
    orElse: () => [],
  );
});

final incomeCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final asyncCategories = ref.watch(categoriesProvider);
  return asyncCategories.maybeWhen(
    data: (cats) => cats.where((c) => c.isIncome).toList(),
    orElse: () => [],
  );
});
