import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/order_models.dart';
import '../../data/orders_repository.dart';

class OrdersState {
  final bool loading;
  final String? error;
  final List<RestaurantOrder> activeOrders;
  final List<RestaurantOrder> historyOrders;

  const OrdersState({
    this.loading = false,
    this.error,
    this.activeOrders = const [],
    this.historyOrders = const [],
  });

  OrdersState copyWith({
    bool? loading,
    String? error,
    List<RestaurantOrder>? activeOrders,
    List<RestaurantOrder>? historyOrders,
    bool clearError = false,
  }) {
    return OrdersState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      activeOrders: activeOrders ?? this.activeOrders,
      historyOrders: historyOrders ?? this.historyOrders,
    );
  }
}

class OrdersCubit extends Cubit<OrdersState> {
  final OrdersRepository _repo;

  OrdersCubit(this._repo) : super(const OrdersState());

  Future<void> loadOrders() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final active = await _repo.getOrders(onlyActive: true);
      final all = await _repo.getOrders(onlyActive: false);
      final history = all.where((o) => !o.isActive).toList();

      emit(state.copyWith(
        loading: false,
        activeOrders: active,
        historyOrders: history,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> updateStatus(String orderId, OrderStatus status) async {
    try {
      await _repo.setStatus(orderId, status);
      await loadOrders();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> markPaid(String orderId) async {
    try {
      await _repo.setPaymentStatus(orderId, PaymentStatus.paid);
      await loadOrders();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
