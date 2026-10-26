import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

class CategoriesNotifier extends StateNotifier<AsyncValue<List<CategoryModel>>> {
  final CategoryRepository _repository;

  CategoriesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      state = const AsyncValue.loading();
      final categories = await _repository.getCategories();
      state = AsyncValue.data(categories);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCategory(CategoryModel category) async {
    await _repository.insertCategory(category);
    await loadCategories();
  }
}

final categoriesProvider = StateNotifierProvider<CategoriesNotifier,
    AsyncValue<List<CategoryModel>>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return CategoriesNotifier(repo);
});

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
