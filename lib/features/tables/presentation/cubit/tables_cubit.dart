import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/table_models.dart';
import '../../data/tables_repository.dart';

class TablesState {
  final bool loading;
  final String? error;
  final List<RestaurantTable> tables;

  const TablesState({
    this.loading = false,
    this.error,
    this.tables = const [],
  });

  TablesState copyWith({
    bool? loading,
    String? error,
    List<RestaurantTable>? tables,
    bool clearError = false,
  }) {
    return TablesState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      tables: tables ?? this.tables,
    );
  }
}

class TablesCubit extends Cubit<TablesState> {
  final TablesRepository _repo;

  TablesCubit(this._repo) : super(const TablesState());

  Future<void> loadTables() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final tables = await _repo.getTables();
      emit(state.copyWith(loading: false, tables: tables));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> changeStatus(String tableId, TableStatus status) async {
    try {
      await _repo.setStatus(tableId, status);
      await loadTables();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> assignOrder(String tableId, String? orderId) async {
    try {
      await _repo.assignOrder(tableId, orderId);
      await loadTables();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> addTable(String name, {int capacity = 4, String section = 'main'}) async {
    try {
      final tables = await _repo.getTables();
      final maxNum = tables.isEmpty ? 0 : tables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b);
      await _repo.createTable(tableNumber: maxNum + 1, name: name, capacity: capacity, section: section);
      await loadTables();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> updateTable(RestaurantTable table) async {
    try {
      await _repo.updateTable(table);
      await loadTables();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> deleteTable(String id) async {
    try {
      await _repo.deleteTable(id);
      await loadTables();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Get available tables for POS table selection
  List<RestaurantTable> get availableTables =>
      state.tables.where((t) => t.status == TableStatus.available).toList();
}
