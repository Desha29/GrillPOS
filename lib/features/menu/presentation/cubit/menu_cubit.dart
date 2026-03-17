import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/menu_models.dart';
import '../../data/menu_repository.dart';

class MenuState {
  final bool loading;
  final String? error;
  final List<MenuCategory> categories;
  final List<MenuItem> items;
  final String? selectedCategoryId;

  const MenuState({
    this.loading = false,
    this.error,
    this.categories = const [],
    this.items = const [],
    this.selectedCategoryId,
  });

  MenuState copyWith({
    bool? loading,
    String? error,
    List<MenuCategory>? categories,
    List<MenuItem>? items,
    String? selectedCategoryId,
    bool clearError = false,
    bool clearSelectedCategory = false,
  }) {
    return MenuState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      categories: categories ?? this.categories,
      items: items ?? this.items,
      selectedCategoryId: clearSelectedCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
    );
  }
}

class MenuCubit extends Cubit<MenuState> {
  final MenuRepository _repo;

  MenuCubit(this._repo) : super(const MenuState());

  Future<void> loadMenu(
      {String? categoryId, bool clearCategory = false}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      // Auto-seed default data if empty
      await _repo.seedDefaultData();

      final categories = await _repo.getCategories();
      final selected =
          clearCategory ? null : (categoryId ?? state.selectedCategoryId);
      final items = await _repo.getMenuItems(categoryId: selected);
      emit(state.copyWith(
        loading: false,
        categories: categories,
        items: items,
        selectedCategoryId: selected,
        clearSelectedCategory: clearCategory,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> selectCategory(String? categoryId) async {
    await loadMenu(categoryId: categoryId, clearCategory: categoryId == null);
  }

  Future<void> addCategory(String name, {String? nameAr}) async {
    try {
      await _repo.createCategory(name: name, nameAr: nameAr);
      await loadMenu(categoryId: state.selectedCategoryId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> addItem({
    required String name,
    String? nameAr,
    required String categoryId,
    required double price,
    String? imageUrl,
    String? description,
    String? unit,
  }) async {
    try {
      await _repo.createItem(
        name: name,
        nameAr: nameAr,
        categoryId: categoryId,
        price: price,
        imageUrl: imageUrl,
        description: description,
        unit: unit,
      );
      await loadMenu(categoryId: state.selectedCategoryId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> toggleItemAvailability(String itemId, bool isAvailable) async {
    try {
      await _repo.toggleAvailability(itemId, isAvailable);
      await loadMenu(categoryId: state.selectedCategoryId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> updateCategory(MenuCategory cat) async {
    try {
      await _repo.updateCategory(cat);
      await loadMenu(categoryId: state.selectedCategoryId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _repo.deleteCategory(id);
      await loadMenu(categoryId: state.selectedCategoryId == id ? null : state.selectedCategoryId, clearCategory: state.selectedCategoryId == id);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> updateItem(MenuItem item) async {
    try {
      await _repo.updateItem(item);
      await loadMenu(categoryId: state.selectedCategoryId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _repo.deleteItem(id);
      await loadMenu(categoryId: state.selectedCategoryId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}

