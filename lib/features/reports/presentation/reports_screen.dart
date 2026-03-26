import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/components/screen_header.dart';
import '../../../core/components/dashboard_stat_card.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../data/reports_repository.dart';
import '../../../core/components/custom_date_range_picker.dart';
import 'cubit/reports_cubit.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ReportsCubit>()..load(),
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      body: SafeArea(
        child: BlocBuilder<ReportsCubit, ReportsState>(
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                  child: ScreenHeader(
                    title: 'التقارير والإحصائيات',
                    subtitle: 'تحليل أداء المبيعات والأصناف الأكثر طلباً',
                    icon: Icons.pie_chart_outline,
                    trailingIcon: Icons.refresh,
                    onTrailingPressed: () => context.read<ReportsCubit>().load(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Filter chips
                Container(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    children: [
                      _FilterChip(
                        label: 'اليوم',
                        filter: ReportFilter.today,
                        selected: state.currentFilter == ReportFilter.today,
                        onTap: () => context.read<ReportsCubit>().load(filter: ReportFilter.today),
                      ),
                      _FilterChip(
                        label: 'أمس',
                        filter: ReportFilter.yesterday,
                        selected: state.currentFilter == ReportFilter.yesterday,
                        onTap: () => context.read<ReportsCubit>().load(filter: ReportFilter.yesterday),
                      ),
                      _FilterChip(
                        label: 'آخر 7 أيام',
                        filter: ReportFilter.week,
                        selected: state.currentFilter == ReportFilter.week,
                        onTap: () => context.read<ReportsCubit>().load(filter: ReportFilter.week),
                      ),
                      _FilterChip(
                        label: 'هذا الشهر',
                        filter: ReportFilter.month,
                        selected: state.currentFilter == ReportFilter.month,
                        onTap: () => context.read<ReportsCubit>().load(filter: ReportFilter.month),
                      ),
                      _FilterChip(
                        label: 'هذه السنة',
                        filter: ReportFilter.year,
                        selected: state.currentFilter == ReportFilter.year,
                        onTap: () => context.read<ReportsCubit>().load(filter: ReportFilter.year),
                      ),
                      _FilterChip(
                        label: 'الكل',
                        filter: ReportFilter.all,
                        selected: state.currentFilter == ReportFilter.all,
                        onTap: () => context.read<ReportsCubit>().load(filter: ReportFilter.all),
                      ),
                      _FilterChip(
                        label: 'مخصص',
                        filter: ReportFilter.custom,
                        selected: state.currentFilter == ReportFilter.custom,
                        onTap: () => _handleCustomRange(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (state.loading && state.summary == null)
                  Expanded(
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.warmOrange))),
                if (state.error != null && state.summary == null)
                  Expanded(
                    child: Center(
                      child: Text(state.error!,
                          style: TextStyle(color: AppColors.grillRed)),
                    ),
                  ),
                if (state.summary != null ||
                    (state.summary == null && !state.loading))
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: _buildStatsGrid(
                        context, state.summary, state.topItems.length),
                  ),
                const SizedBox(height: AppSpacing.md),
                if (state.summary != null ||
                    (state.summary == null && !state.loading))
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      children: [
                        _ChartCard(
                          title: 'اتجاه الإيرادات (آخر 7 أيام)',
                          subtitle: 'متابعة النمو اليومي للمبيعات',
                          child: SizedBox(
                              height: 240,
                              child: _TrendChart(points: state.trend)),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ChartCard(
                          title: 'الأصناف الأكثر مبيعاً',
                          subtitle: 'ترتيب الأصناف حسب كمية الطلب',
                          child: SizedBox(
                              height: 240,
                              child: _TopItemsChart(items: state.topItems)),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handleCustomRange(BuildContext context) async {
    final DateTimeRange? picked = await CustomDateRangePicker.show(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      context.read<ReportsCubit>().load(
            filter: ReportFilter.custom,
            from: picked.start,
            to: picked.end,
          );
    }
  }

  Widget _buildStatsGrid(
      BuildContext context, ReportsSummary? summary, int topItemsCount) {
    final s = summary ??
        const ReportsSummary(revenue: 0, ordersCount: 0, avgOrder: 0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 1100 ? 4 : width > 600 ? 2 : 2;
        final childAspectRatio = width > 1100 ? 2.2 : width > 600 ? 2.2 : 1.3;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: childAspectRatio,
          children: [
            DashboardStatCard(
              title: 'الإيرادات',
              value: '${s.revenue.toStringAsFixed(2)} ج.م',
              icon: Icons.attach_money,
              color: AppColors.warmOrange,
              trend: 'اليوم',
              isPositiveTrend: true,
            ),
            DashboardStatCard(
              title: 'الطلبات',
              value: '${s.ordersCount}',
              icon: Icons.receipt_long,
              color: AppColors.ember,
              trend: 'مباشر',
              isPositiveTrend: true,
            ),
            DashboardStatCard(
              title: 'متوسط الطلب',
              value: '${s.avgOrder.toStringAsFixed(2)} ج.م',
              icon: Icons.show_chart,
              color: AppColors.successGreen,
              trend: 'لكل فاتورة',
              isPositiveTrend: true,
            ),
            DashboardStatCard(
              title: 'أهم الأصناف',
              value: '$topItemsCount',
              icon: Icons.local_fire_department,
              color: AppColors.grillRed,
              trend: 'نشطة',
              isPositiveTrend: true,
            ),
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(color: AppColors.creamMuted, fontSize: 12)),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<DailyRevenuePoint> points;

  const _TrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart,
                size: 48, color: AppColors.mutedColor.withOpacity(0.4)),
            const SizedBox(height: AppSpacing.sm),
            Text('لا توجد بيانات',
                style: TextStyle(color: AppColors.creamMuted)),
          ],
        ),
      );
    }

    return LineChart(
      LineChartData(
        backgroundColor: Colors.transparent,
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.charcoalDark,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                return LineTooltipItem(
                  '${touchedSpot.y.toStringAsFixed(1)} ج.م',
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1000,
          getDrawingHorizontalLine: (value) {
            return FlLine(
                color: AppColors.borderColor.withOpacity(0.5), strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < points.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      points[value.toInt()].day.length >= 10
                          ? points[value.toInt()].day.substring(5)
                          : points[value.toInt()].day,
                      style: TextStyle(
                          color: AppColors.creamMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 32,
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toInt() >= 1000
                        ? '${(value / 1000).toStringAsFixed(1)}k'
                        : value.toInt().toString(),
                    style: TextStyle(color: AppColors.mutedColor, fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                );
              },
              reservedSize: 45,
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: AppColors.warmOrange,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.warmOrange,
                  strokeWidth: 2,
                  strokeColor: AppColors.surfaceDark,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.warmOrange.withOpacity(0.5),
                  AppColors.warmOrange.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            spots: List.generate(
              points.length,
              (i) => FlSpot(i.toDouble(), points[i].value),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopItemsChart extends StatelessWidget {
  final List<TopItem> items;

  const _TopItemsChart({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart,
                size: 48, color: AppColors.mutedColor.withOpacity(0.4)),
            const SizedBox(height: AppSpacing.sm),
            Text('لا توجد بيانات',
                style: TextStyle(color: AppColors.creamMuted)),
          ],
        ),
      );
    }

    final bars = items.take(6).toList();

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.charcoalDark,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${bars[groupIndex].name}\n${rod.toY.toInt()} طلب',
                const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) {
            return FlLine(
                color: AppColors.borderColor.withOpacity(0.5), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < bars.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      bars[value.toInt()].name,
                      style: TextStyle(
                          color: AppColors.creamMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(color: AppColors.mutedColor, fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                );
              },
              reservedSize: 35,
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: List.generate(
          bars.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: bars[i].qty.toDouble(),
                gradient: LinearGradient(
                  colors: [AppColors.ember, AppColors.warmOrange],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
                width: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final ReportFilter filter;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.warmOrange,
        backgroundColor: AppColors.surfaceDark,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.creamMuted,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? AppColors.warmOrange : AppColors.borderColor,
          ),
        ),
      ),
    );
  }
}

