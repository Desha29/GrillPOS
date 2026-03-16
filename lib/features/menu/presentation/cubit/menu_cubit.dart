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
  }) {
    return MenuState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      categories: categories ?? this.categories,
      items: items ?? this.items,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
    );
  }
}

class MenuCubit extends Cubit<MenuState> {
  final MenuRepository _repo;

  MenuCubit(this._repo) : super(const MenuState());

  Future<void> loadMenu({String? categoryId}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final categories = await _repo.getCategories();
      final selected = categoryId ?? state.selectedCategoryId;
      final items = await _repo.getMenuItems(categoryId: selected);
      emit(state.copyWith(
        loading: false,
        categories: categories,
        items: items,
        selectedCategoryId: selected,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> selectCategory(String? categoryId) async {
    emit(state.copyWith(selectedCategoryId: categoryId));
    await loadMenu(categoryId: categoryId);
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
  }) async {
    try {
      await _repo.createItem(
        name: name,
        nameAr: nameAr,
        categoryId: categoryId,
        price: price,
        imageUrl: imageUrl,
        description: description,
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
}
