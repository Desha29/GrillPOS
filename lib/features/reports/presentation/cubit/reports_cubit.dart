import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../reports/data/reports_repository.dart';

enum ReportFilter { today, yesterday, week, month, year, all, custom }

class ReportsState {
  final bool loading;
  final String? error;
  final ReportsSummary? summary;
  final List<TopItem> topItems;
  final List<CategorySales> categorySales;
  final List<DailyRevenuePoint> trend;
  final ReportFilter currentFilter;
  final DateTime? customFrom;
  final DateTime? customTo;

  const ReportsState({
    this.loading = false,
    this.error,
    this.summary,
    this.topItems = const [],
    this.categorySales = const [],
    this.trend = const [],
    this.currentFilter = ReportFilter.today,
    this.customFrom,
    this.customTo,
  });

  ReportsState copyWith({
    bool? loading,
    String? error,
    ReportsSummary? summary,
    List<TopItem>? topItems,
    List<CategorySales>? categorySales,
    List<DailyRevenuePoint>? trend,
    ReportFilter? currentFilter,
    DateTime? customFrom,
    DateTime? customTo,
    bool clearError = false,
  }) {
    return ReportsState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      summary: summary ?? this.summary,
      topItems: topItems ?? this.topItems,
      categorySales: categorySales ?? this.categorySales,
      trend: trend ?? this.trend,
      currentFilter: currentFilter ?? this.currentFilter,
      customFrom: customFrom ?? this.customFrom,
      customTo: customTo ?? this.customTo,
    );
  }
}

class ReportsCubit extends Cubit<ReportsState> {
  final ReportsRepository _repo;

  ReportsCubit(this._repo) : super(const ReportsState());

  Future<void> load({ReportFilter? filter, DateTime? from, DateTime? to}) async {
    final activeFilter = filter ?? state.currentFilter;
    final startFrom = from ?? state.customFrom;
    final endTo = to ?? state.customTo;

    emit(state.copyWith(
      loading: true,
      clearError: true,
      currentFilter: activeFilter,
      customFrom: startFrom,
      customTo: endTo,
    ));

    try {
      DateTime? effectiveFrom;
      DateTime? effectiveTo;
      final now = DateTime.now();

      switch (activeFilter) {
        case ReportFilter.today:
          effectiveFrom = DateTime(now.year, now.month, now.day);
          break;
        case ReportFilter.yesterday:
          effectiveFrom = DateTime(now.year, now.month, now.day - 1);
          effectiveTo = DateTime(now.year, now.month, now.day, 0, 0, -1);
          break;
        case ReportFilter.week:
          effectiveFrom = now.subtract(const Duration(days: 7));
          break;
        case ReportFilter.month:
          effectiveFrom = DateTime(now.year, now.month, 1);
          break;
        case ReportFilter.year:
          effectiveFrom = DateTime(now.year, 1, 1);
          break;
        case ReportFilter.all:
          effectiveFrom = null;
          break;
        case ReportFilter.custom:
          effectiveFrom = startFrom;
          effectiveTo = endTo;
          break;
      }

      final summary =
          await _repo.getSummary(from: effectiveFrom, to: effectiveTo);
      final topItems =
          await _repo.getTopItems(from: effectiveFrom, to: effectiveTo);
      final categorySales =
          await _repo.getSalesByCategory(from: effectiveFrom, to: effectiveTo);
      
      final trend = await _repo.getDailyRevenueTrend(
        from: effectiveFrom,
        to: effectiveTo,
        limit: activeFilter == ReportFilter.month ? 31 : (activeFilter == ReportFilter.year ? 365 : 7),
      );

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
