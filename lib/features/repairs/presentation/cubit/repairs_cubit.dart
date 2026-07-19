import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repair_models.dart';
import '../../data/repairs_repository.dart';

class RepairsState {
  const RepairsState({
    this.loading = false,
    this.saving = false,
    this.tickets = const [],
    this.stats = const RepairStats(),
    this.search = '',
    this.status,
    this.error,
  });

  final bool loading;
  final bool saving;
  final List<RepairTicket> tickets;
  final RepairStats stats;
  final String search;
  final RepairStatus? status;
  final String? error;

  RepairsState copyWith({
    bool? loading,
    bool? saving,
    List<RepairTicket>? tickets,
    RepairStats? stats,
    String? search,
    RepairStatus? status,
    bool clearStatus = false,
    String? error,
    bool clearError = false,
  }) =>
      RepairsState(
        loading: loading ?? this.loading,
        saving: saving ?? this.saving,
        tickets: tickets ?? this.tickets,
        stats: stats ?? this.stats,
        search: search ?? this.search,
        status: clearStatus ? null : status ?? this.status,
        error: clearError ? null : error ?? this.error,
      );
}

class RepairsCubit extends Cubit<RepairsState> {
  RepairsCubit(this._repository) : super(const RepairsState()) {
    _subscription = _repository.changes.listen((_) => load());
  }

  final RepairsRepository _repository;
  StreamSubscription<void>? _subscription;

  Future<void> load({String? search, RepairStatus? status, bool? all}) async {
    final nextSearch = search ?? state.search;
    final nextStatus = all == true ? null : status ?? state.status;
    emit(state.copyWith(
      loading: true,
      search: nextSearch,
      status: nextStatus,
      clearStatus: all == true,
      clearError: true,
    ));
    try {
      final results = await Future.wait<Object>([
        _repository.getTickets(search: nextSearch, status: nextStatus),
        _repository.getStats(),
      ]);
      emit(state.copyWith(
        loading: false,
        tickets: results[0] as List<RepairTicket>,
        stats: results[1] as RepairStats,
      ));
    } catch (error) {
      emit(state.copyWith(loading: false, error: error.toString()));
    }
  }

  Future<RepairTicket?> create(NewRepairTicketInput input) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final ticket = await _repository.createTicket(input);
      emit(state.copyWith(saving: false));
      return ticket;
    } catch (error) {
      emit(state.copyWith(saving: false, error: error.toString()));
      return null;
    }
  }

  Future<bool> update(RepairTicket ticket, {String? changedBy}) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repository.updateTicket(ticket, changedBy: changedBy);
      emit(state.copyWith(saving: false));
      return true;
    } catch (error) {
      emit(state.copyWith(saving: false, error: error.toString()));
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
