import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/inventory_models.dart';
import '../../data/inventory_repository.dart';

class InventoryState {
  const InventoryState({
    this.loading = false,
    this.saving = false,
    this.products = const [],
    this.suppliers = const [],
    this.stats = const InventoryStats(),
    this.search = '',
    this.lowStockOnly = false,
    this.error,
  });

  final bool loading;
  final bool saving;
  final List<InventoryProduct> products;
  final List<Supplier> suppliers;
  final InventoryStats stats;
  final String search;
  final bool lowStockOnly;
  final String? error;

  InventoryState copyWith({
    bool? loading,
    bool? saving,
    List<InventoryProduct>? products,
    List<Supplier>? suppliers,
    InventoryStats? stats,
    String? search,
    bool? lowStockOnly,
    String? error,
    bool clearError = false,
  }) =>
      InventoryState(
        loading: loading ?? this.loading,
        saving: saving ?? this.saving,
        products: products ?? this.products,
        suppliers: suppliers ?? this.suppliers,
        stats: stats ?? this.stats,
        search: search ?? this.search,
        lowStockOnly: lowStockOnly ?? this.lowStockOnly,
        error: clearError ? null : error ?? this.error,
      );
}

class InventoryCubit extends Cubit<InventoryState> {
  InventoryCubit(this._repository) : super(const InventoryState()) {
    _subscription = _repository.changes.listen((_) => load());
  }

  final InventoryRepository _repository;
  StreamSubscription<void>? _subscription;

  Future<void> load({String? search, bool? lowStockOnly}) async {
    final nextSearch = search ?? state.search;
    final nextLowStock = lowStockOnly ?? state.lowStockOnly;
    emit(state.copyWith(
      loading: true,
      search: nextSearch,
      lowStockOnly: nextLowStock,
      clearError: true,
    ));
    try {
      final values = await Future.wait<Object>([
        _repository.getProducts(search: nextSearch, lowStockOnly: nextLowStock),
        _repository.getSuppliers(),
        _repository.getStats(),
      ]);
      emit(state.copyWith(
        loading: false,
        products: values[0] as List<InventoryProduct>,
        suppliers: values[1] as List<Supplier>,
        stats: values[2] as InventoryStats,
      ));
    } catch (error) {
      emit(state.copyWith(loading: false, error: _friendlyError(error)));
    }
  }

  Future<bool> createProduct(
    NewInventoryProductInput input, {
    String? userId,
  }) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repository.createProduct(input, userId: userId);
      emit(state.copyWith(saving: false));
      return true;
    } catch (error) {
      emit(state.copyWith(saving: false, error: _friendlyError(error)));
      return false;
    }
  }

  Future<bool> updateProduct(
    InventoryProduct product,
    NewInventoryProductInput input,
  ) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repository.updateProduct(product, input);
      emit(state.copyWith(saving: false));
      return true;
    } catch (error) {
      emit(state.copyWith(saving: false, error: _friendlyError(error)));
      return false;
    }
  }

  Future<bool> createSupplier(NewSupplierInput input) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repository.createSupplier(input);
      emit(state.copyWith(saving: false));
      return true;
    } catch (error) {
      emit(state.copyWith(saving: false, error: _friendlyError(error)));
      return false;
    }
  }

  Future<bool> adjustStock(
    InventoryProduct product,
    double quantity,
    String note, {
    String? userId,
  }) async {
    try {
      await _repository.adjustStock(product, quantity,
          note: note, userId: userId);
      return true;
    } catch (error) {
      emit(state.copyWith(error: _friendlyError(error)));
      return false;
    }
  }

  Future<bool> addSerials(
    InventoryProduct product,
    List<String> serials, {
    String? userId,
  }) async {
    try {
      await _repository.addSerials(product, serials, userId: userId);
      return true;
    } catch (error) {
      emit(state.copyWith(error: _friendlyError(error)));
      return false;
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    final normalized = message.toLowerCase();
    if (normalized.contains('unique constraint') ||
        normalized.contains('sqlite_constraint_unique')) {
      if (normalized.contains('serial')) {
        return 'One or more serial numbers already exist in inventory.';
      }
      return 'This SKU or barcode is already used by another product.';
    }
    if (error is ArgumentError || error is StateError) {
      return message
          .replaceFirst('Invalid argument(s): ', '')
          .replaceFirst('Bad state: ', '');
    }
    return 'The inventory change could not be saved. Please try again.';
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
