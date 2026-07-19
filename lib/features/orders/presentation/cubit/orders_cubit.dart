import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../../core/security/permission_guard.dart';
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
  int _loadRequest = 0;

  OrdersCubit(this._repo) : super(const OrdersState());

  Future<void> loadOrders() async {
    final request = ++_loadRequest;
    if (isClosed) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final all = await _repo.getOrders(onlyActive: false);
      if (isClosed || request != _loadRequest) return;
      final active = all.where((o) => o.isActive).toList();
      final history = all.where((o) => !o.isActive).toList();

      emit(state.copyWith(
        loading: false,
        activeOrders: active,
        historyOrders: history,
      ));
    } catch (e) {
      if (isClosed || request != _loadRequest) return;
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> updateStatus(
    RestaurantOrder order,
    OrderStatus status, {
    required User actor,
  }) async {
    try {
      PermissionGuard.require(
        actor,
        AppPermission.updateOrders,
        message: 'ليس لديك صلاحية تحديث حالة الطلبات.',
      );
      await _repo.transitionStatus(
        orderId: order.id,
        expectedCurrent: order.status,
        next: status,
        actorId: actor.username,
      );
      await loadOrders();
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> markPaid(
    RestaurantOrder order, {
    required User actor,
    String method = 'cash',
    String? referenceNumber,
  }) async {
    try {
      PermissionGuard.require(
        actor,
        AppPermission.processPayments,
        message: 'ليس لديك صلاحية تسجيل المدفوعات.',
      );
      await _repo.recordRemainingPayment(
        orderId: order.id,
        actorId: actor.username,
        method: method,
        referenceNumber: referenceNumber,
      );
      await loadOrders();
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.toString()));
    }
  }
}
