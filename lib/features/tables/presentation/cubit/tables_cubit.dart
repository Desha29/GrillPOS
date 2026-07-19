import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/security/permission_guard.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/table_models.dart';
import '../../data/tables_repository.dart';

class TablesState {
  const TablesState({
    this.loading = false,
    this.saving = false,
    this.error,
    this.notice,
    this.tables = const [],
  });

  final bool loading;
  final bool saving;
  final String? error;
  final String? notice;
  final List<RestaurantTable> tables;

  TablesState copyWith({
    bool? loading,
    bool? saving,
    String? error,
    String? notice,
    List<RestaurantTable>? tables,
    bool clearMessages = false,
  }) {
    return TablesState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      error: clearMessages ? null : error ?? this.error,
      notice: clearMessages ? null : notice ?? this.notice,
      tables: tables ?? this.tables,
    );
  }
}

class TablesCubit extends Cubit<TablesState> {
  TablesCubit(
    this._repository, {
    required User Function() currentUser,
  })  : _currentUser = currentUser,
        super(const TablesState());

  final TablesRepository _repository;
  final User Function() _currentUser;
  int _loadRevision = 0;

  Future<void> loadTables() async {
    final revision = ++_loadRevision;
    if (isClosed) return;
    emit(state.copyWith(loading: true, clearMessages: true));
    try {
      final tables = await _repository.getTables();
      if (isClosed || revision != _loadRevision) return;
      emit(state.copyWith(loading: false, tables: tables));
    } catch (error) {
      if (isClosed || revision != _loadRevision) return;
      emit(state.copyWith(loading: false, error: _friendly(error)));
    }
  }

  Future<bool> changeStatus(String tableId, TableStatus status) {
    return _mutate(
      operation: () => _repository.setStatus(tableId, status),
      success: 'تم تحديث حالة الطاولة.',
    );
  }

  Future<bool> assignOrder(String tableId, String? orderId) {
    return _mutate(
      operation: () => _repository.assignOrder(tableId, orderId),
      success: orderId == null ? 'تم تحرير الطاولة.' : 'تم ربط الطلب بالطاولة.',
    );
  }

  Future<bool> addTable(
    String? name, {
    int capacity = 4,
    String section = 'main',
  }) {
    return _mutate(
      operation: () => _repository.createTable(
        name: name,
        capacity: capacity,
        section: section,
      ),
      success: 'تمت إضافة الطاولة بنجاح.',
    );
  }

  Future<bool> updateTable(RestaurantTable table) {
    return _mutate(
      operation: () => _repository.updateTable(table),
      success: 'تم حفظ بيانات الطاولة.',
    );
  }

  Future<bool> deleteTable(String id) {
    return _mutate(
      operation: () => _repository.deleteTable(id),
      success: 'تم حذف الطاولة.',
    );
  }

  List<RestaurantTable> get availableTables => state.tables
      .where((table) => table.status == TableStatus.available)
      .toList(growable: false);

  Future<bool> _mutate({
    required Future<dynamic> Function() operation,
    required String success,
  }) async {
    try {
      PermissionGuard.require(
        _currentUser(),
        AppPermission.manageTables,
        message: 'ليس لديك صلاحية إدارة الطاولات.',
      );
      if (!isClosed) {
        emit(state.copyWith(saving: true, clearMessages: true));
      }
      await operation();
      final tables = await _repository.getTables();
      if (isClosed) return true;
      _loadRevision++;
      emit(state.copyWith(
        loading: false,
        saving: false,
        tables: tables,
        notice: success,
      ));
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(saving: false, error: _friendly(error)));
      }
      return false;
    }
  }

  String _friendly(Object error) {
    if (error is TablesException) return error.message;
    if (error is PermissionDeniedException) return error.message;
    final value = error.toString().toLowerCase();
    if (value.contains('foreign key')) {
      return 'لا يمكن تنفيذ الإجراء لأن الطاولة مرتبطة بسجل آخر.';
    }
    return 'تعذر تنفيذ الإجراء على الطاولة. حاول مرة أخرى.';
  }
}
