import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/components/screen_header.dart';
import '../../../core/components/dashboard_stat_card.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../data/reports_repository.dart';
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
                const SizedBox(height: AppSpacing.md),
                if (state.loading && state.summary == null)
                  Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.warmOrange))),
                if (state.error != null && state.summary == null)
                  Expanded(
                    child: Center(
                      child: Text(state.error!, style: TextStyle(color: AppColors.grillRed)),
                    ),
                  ),
                if (state.summary != null || (state.summary == null && !state.loading))
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      children: [
                        _buildStatsGrid(context, state.summary, state.topItems.length),
                        const SizedBox(height: AppSpacing.lg),
                        _ChartCard(
                          title: 'اتجاه الإيرادات (آخر 7 أيام)',
                          subtitle: 'متابعة النمو اليومي للمبيعات',
                          child: SizedBox(height: 240, child: _TrendChart(points: state.trend)),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ChartCard(
                          title: 'الأصناف الأكثر مبيعاً',
                          subtitle: 'ترتيب الأصناف حسب كمية الطلب',
                          child: SizedBox(height: 240, child: _TopItemsChart(items: state.topItems)),
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

  Widget _buildStatsGrid(BuildContext context, ReportsSummary? summary, int topItemsCount) {
    final s = summary ?? const ReportsSummary(revenue: 0, ordersCount: 0, avgOrder: 0);
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
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
              style: TextStyle(color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.bold)),
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
            Icon(Icons.show_chart, size: 48, color: AppColors.mutedColor.withOpacity(0.4)),
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
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(
            show: true, border: Border.all(color: AppColors.borderColor)),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: AppColors.warmOrange,
            barWidth: 3,
            spots: List.generate(
              points.length,
              (i) => FlSpot(i.toDouble(), points[i].value),
            ),
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.warmOrange.withOpacity(0.1),
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
            Icon(Icons.bar_chart, size: 48, color: AppColors.mutedColor.withOpacity(0.4)),
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
        borderData: FlBorderData(
            show: true, border: Border.all(color: AppColors.borderColor)),
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: true),
        barGroups: List.generate(
          bars.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: bars[i].qty.toDouble(),
                color: AppColors.ember,
                borderRadius: BorderRadius.circular(6),
                width: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
