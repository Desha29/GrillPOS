import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../menu/data/menu_models.dart';
import '../../../menu/data/menu_repository.dart';
import '../../../orders/data/order_models.dart';
import '../../../orders/data/orders_repository.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../tables/data/tables_repository.dart';
import '../../../tables/presentation/cubit/tables_cubit.dart';

class PosCartItem {
  final MenuItem item;
  final int quantity;

  const PosCartItem({required this.item, required this.quantity});

  double get lineTotal => item.price * quantity;

  PosCartItem copyWith({int? quantity}) {
    return PosCartItem(item: item, quantity: quantity ?? this.quantity);
  }
}

class POSState {
  final bool loading;
  final String? error;
  final List<MenuCategory> categories;
  final List<MenuItem> visibleItems;
  final String? selectedCategoryId;
  final OrderType orderType;
  final String? selectedTableId;
  final List<PosCartItem> cart;
  final double taxRate;

  const POSState({
    this.loading = false,
    this.error,
    this.categories = const [],
    this.visibleItems = const [],
    this.selectedCategoryId,
    this.orderType = OrderType.dineIn,
    this.selectedTableId,
    this.cart = const [],
    this.taxRate = 0.15,
  });

  double get subtotal => cart.fold(0, (sum, c) => sum + c.lineTotal);
  double get tax => subtotal * taxRate;
  double get total => subtotal + tax;

  POSState copyWith({
    bool? loading,
    String? error,
    List<MenuCategory>? categories,
    List<MenuItem>? visibleItems,
    String? selectedCategoryId,
    OrderType? orderType,
    String? selectedTableId,
    List<PosCartItem>? cart,
    double? taxRate,
    bool clearError = false,
  }) {
    return POSState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      categories: categories ?? this.categories,
      visibleItems: visibleItems ?? this.visibleItems,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      orderType: orderType ?? this.orderType,
      selectedTableId: selectedTableId ?? this.selectedTableId,
      cart: cart ?? this.cart,
      taxRate: taxRate ?? this.taxRate,
    );
  }
}

class POSCubit extends Cubit<POSState> {
  final MenuRepository _menuRepo;
  final OrdersRepository _ordersRepo;

  POSCubit(this._menuRepo, this._ordersRepo) : super(const POSState());

  Future<void> loadMenu({String? categoryId}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final categories = await _menuRepo.getCategories();
      final selected = categoryId ?? state.selectedCategoryId;
      final items = await _menuRepo.getAvailableItems(categoryId: selected);
      emit(state.copyWith(
        loading: false,
        categories: categories,
        selectedCategoryId: selected,
        visibleItems: items,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> selectCategory(String? categoryId) async {
    await loadMenu(categoryId: categoryId);
  }

  void setOrderType(OrderType type) {
    emit(state.copyWith(orderType: type));
  }

  void selectTable(String? tableId) {
    emit(state.copyWith(selectedTableId: tableId));
  }

  void setTaxRate(double rate) {
    emit(state.copyWith(taxRate: rate));
  }

  void addToCart(MenuItem item) {
    final idx = state.cart.indexWhere((c) => c.item.id == item.id);
    if (idx == -1) {
      emit(state.copyWith(
          cart: [...state.cart, PosCartItem(item: item, quantity: 1)]));
      return;
    }

    final updated = [...state.cart];
    updated[idx] = updated[idx].copyWith(quantity: updated[idx].quantity + 1);
    emit(state.copyWith(cart: updated));
  }

  void decrementItem(String menuItemId) {
    final idx = state.cart.indexWhere((c) => c.item.id == menuItemId);
    if (idx == -1) return;

    final current = state.cart[idx];
    if (current.quantity <= 1) {
      removeFromCart(menuItemId);
      return;
    }

    final updated = [...state.cart];
    updated[idx] = current.copyWith(quantity: current.quantity - 1);
    emit(state.copyWith(cart: updated));
  }

  void removeFromCart(String menuItemId) {
    emit(state.copyWith(
        cart: state.cart.where((c) => c.item.id != menuItemId).toList()));
  }

  void clearCart() {
    emit(state.copyWith(cart: []));
  }

  Future<String?> checkout(
      {String? cashierId, String? waiterId, String? notes}) async {
    if (state.cart.isEmpty) return null;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      final order = await _ordersRepo.createOrder(
        tableId: state.selectedTableId,
        orderType: state.orderType,
        cashierId: cashierId,
        waiterId: waiterId,
        notes: notes,
      );

      for (final c in state.cart) {
        await _ordersRepo.addOrderItem(
          orderId: order.id,
          menuItemId: c.item.id,
          itemName: c.item.displayName,
          quantity: c.quantity,
          unitPrice: c.item.price,
        );
      }

      if (state.selectedTableId != null && state.orderType == OrderType.dineIn) {
        try {
          await getIt<TablesRepository>().assignOrder(state.selectedTableId!, order.id);
          getIt<TablesCubit>().loadTables();
        } catch (_) {}
      }

      emit(state.copyWith(loading: false, cart: []));
      return order.id;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      return null;
    }
  }
}
