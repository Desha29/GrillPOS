import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../reports/data/reports_repository.dart';

class ReportsState {
  final bool loading;
  final String? error;
  final ReportsSummary? summary;
  final List<TopItem> topItems;
  final List<CategorySales> categorySales;
  final List<DailyRevenuePoint> trend;

  const ReportsState({
    this.loading = false,
    this.error,
    this.summary,
    this.topItems = const [],
    this.categorySales = const [],
    this.trend = const [],
  });

  ReportsState copyWith({
    bool? loading,
    String? error,
    ReportsSummary? summary,
    List<TopItem>? topItems,
    List<CategorySales>? categorySales,
    List<DailyRevenuePoint>? trend,
    bool clearError = false,
  }) {
    return ReportsState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      summary: summary ?? this.summary,
      topItems: topItems ?? this.topItems,
      categorySales: categorySales ?? this.categorySales,
      trend: trend ?? this.trend,
    );
  }
}

class ReportsCubit extends Cubit<ReportsState> {
  final ReportsRepository _repo;

  ReportsCubit(this._repo) : super(const ReportsState());

  Future<void> load({DateTime? from, DateTime? to}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final summary = await _repo.getSummary(from: from, to: to);
      final topItems = await _repo.getTopItems(from: from, to: to);
      final categorySales = await _repo.getSalesByCategory(from: from, to: to);
      final trend = await _repo.getDailyRevenueTrend(days: 7);

      emit(state.copyWith(
        loading: false,
        summary: summary,
        topItems: topItems,
        categorySales: categorySales,
        trend: trend,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }
}
