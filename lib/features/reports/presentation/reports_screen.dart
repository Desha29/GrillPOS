import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/components/custom_date_range_picker.dart';
import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../data/reports_repository.dart';
import 'cubit/reports_cubit.dart';
import 'report_details_screen.dart';

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
            return Stack(
              children: [
                RefreshIndicator(
                  color: AppColors.warmOrange,
                  onRefresh: () => context.read<ReportsCubit>().load(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.xl,
                        ),
                        sliver: SliverList.list(
                          children: [
                            _ReportsHeader(state: state),
                            const SizedBox(height: AppSpacing.md),
                            _PeriodToolbar(state: state),
                            const SizedBox(height: AppSpacing.lg),
                            if (state.error != null) ...[
                              _ErrorBanner(message: state.error!),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (state.loading && state.summary == null)
                              const _ReportsSkeleton()
                            else ...[
                              _MetricsGrid(state: state),
                              const SizedBox(height: AppSpacing.md),
                              _AnalyticsLayout(state: state),
                              const SizedBox(height: AppSpacing.md),
                              _TopProductsCard(items: state.topItems),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.loading && state.summary != null)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({required this.state});

  final ReportsState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (state.summary != null)
              OutlinedButton.icon(
                onPressed: () => _openDetails(context),
                icon: const Icon(LucideIcons.fileChartColumn, size: 17),
                label: Text(compact ? 'التفاصيل' : 'التقرير المفصل'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warmOrange,
                  side: BorderSide(
                    color: AppColors.warmOrange.withValues(alpha: .42),
                  ),
                  backgroundColor: AppColors.warmOrange.withValues(alpha: .065),
                ),
              ),
            _SquareActionButton(
              icon: LucideIcons.refreshCw,
              tooltip: 'تحديث البيانات',
              onTap: state.loading
                  ? null
                  : () => context.read<ReportsCubit>().load(),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(
                title: 'التقارير والإحصائيات',
                subtitle: 'صورة واضحة لأداء المبيعات واتجاهاتها',
                icon: LucideIcons.chartNoAxesCombined,
              ),
              const SizedBox(height: 8),
              Align(alignment: AlignmentDirectional.centerEnd, child: actions),
            ],
          );
        }

        return ScreenHeader(
          title: 'التقارير والإحصائيات',
          subtitle: 'صورة واضحة لأداء المبيعات واتجاهاتها',
          icon: LucideIcons.chartNoAxesCombined,
          trailingWidget: actions,
        );
      },
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailsScreen(
          summary: state.summary!,
          topItems: state.topItems,
          reportTitle: state.currentFilter == ReportFilter.today
              ? 'تقرير مبيعات اليوم'
              : 'تقرير المبيعات التفصيلي',
          from: state.customFrom,
          to: state.customTo,
        ),
      ),
    );
  }
}

class _SquareActionButton extends StatelessWidget {
  const _SquareActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Icon(icon, size: 19, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _PeriodToolbar extends StatelessWidget {
  const _PeriodToolbar({required this.state});

  final ReportsState state;

  static const filters = <(ReportFilter, String, IconData)>[
    (ReportFilter.today, 'اليوم', LucideIcons.sun),
    (ReportFilter.yesterday, 'أمس', LucideIcons.history),
    (ReportFilter.week, '7 أيام', LucideIcons.calendarDays),
    (ReportFilter.month, 'هذا الشهر', LucideIcons.calendarRange),
    (ReportFilter.year, 'هذه السنة', LucideIcons.calendar),
    (ReportFilter.all, 'كل الفترات', LucideIcons.infinity),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in filters) ...[
                    _PeriodOption(
                      label: item.$2,
                      icon: item.$3,
                      selected: state.currentFilter == item.$1,
                      onTap: () =>
                          context.read<ReportsCubit>().load(filter: item.$1),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CustomPeriodButton(
            selected: state.currentFilter == ReportFilter.custom,
            label: _customRangeLabel(state),
            onTap: () => _handleCustomRange(context),
          ),
        ],
      ),
    );
  }

  String _customRangeLabel(ReportsState state) {
    if (state.currentFilter != ReportFilter.custom ||
        state.customFrom == null ||
        state.customTo == null) {
      return 'فترة مخصصة';
    }
    final formatter = DateFormat('d/M');
    return '${formatter.format(state.customFrom!)} - ${formatter.format(state.customTo!)}';
  }

  Future<void> _handleCustomRange(BuildContext context) async {
    final picked = await CustomDateRangePicker.show(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && context.mounted) {
      context.read<ReportsCubit>().load(
            filter: ReportFilter.custom,
            from: picked.start,
            to: picked.end,
          );
    }
  }
}

class _PeriodOption extends StatelessWidget {
  const _PeriodOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.warmOrange.withValues(alpha: .12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.warmOrange.withValues(alpha: .35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color:
                    selected ? AppColors.warmOrange : AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? AppColors.warmOrange : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomPeriodButton extends StatelessWidget {
  const _CustomPeriodButton({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(LucideIcons.slidersHorizontal, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            selected ? AppColors.warmOrange : AppColors.textSecondary,
        backgroundColor: selected
            ? AppColors.warmOrange.withValues(alpha: .08)
            : AppColors.charcoalLight,
        side: BorderSide(
          color: selected
              ? AppColors.warmOrange.withValues(alpha: .45)
              : AppColors.borderColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.state});

  final ReportsState state;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary ??
        const ReportsSummary(revenue: 0, ordersCount: 0, avgOrder: 0);
    final metrics = [
      _MetricData(
        title: 'إجمالي الإيرادات',
        value: _formatMoney(summary.revenue),
        caption: _filterCaption(state.currentFilter),
        icon: LucideIcons.walletCards,
        color: AppColors.warmOrange,
      ),
      _MetricData(
        title: 'الطلبات المكتملة',
        value: NumberFormat.decimalPattern('ar').format(summary.ordersCount),
        caption: 'طلب مكتمل',
        icon: LucideIcons.receiptText,
        color: AppColors.ember,
      ),
      _MetricData(
        title: 'متوسط قيمة الطلب',
        value: _formatMoney(summary.avgOrder),
        caption: 'لكل فاتورة',
        icon: LucideIcons.chartNoAxesColumnIncreasing,
        color: AppColors.successGreen,
      ),
      _MetricData(
        title: 'الأصناف النشطة',
        value: NumberFormat.decimalPattern('ar').format(state.topItems.length),
        caption: 'ضمن الأعلى مبيعاً',
        icon: LucideIcons.flame,
        color: AppColors.grillRed,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final gap = AppSpacing.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics)
              SizedBox(width: width, child: _MetricCard(data: metric)),
          ],
        );
      },
    );
  }

  static String _filterCaption(ReportFilter filter) => switch (filter) {
        ReportFilter.today => 'مبيعات اليوم',
        ReportFilter.yesterday => 'مبيعات أمس',
        ReportFilter.week => 'آخر 7 أيام',
        ReportFilter.month => 'الشهر الحالي',
        ReportFilter.year => 'السنة الحالية',
        ReportFilter.all => 'كل الفترات',
        ReportFilter.custom => 'الفترة المحددة',
      };
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 126,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: data.color, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    data.value,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: data.color, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsLayout extends StatelessWidget {
  const _AnalyticsLayout({required this.state});

  final ReportsState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final trend = _InsightCard(
          title: 'اتجاه الإيرادات',
          subtitle: 'حركة المبيعات خلال الفترة المختارة',
          icon: LucideIcons.trendingUp,
          accent: AppColors.warmOrange,
          child: SizedBox(
            height: 260,
            child: _TrendChart(points: state.trend),
          ),
        );
        final categories = _InsightCard(
          title: 'أداء الأقسام',
          subtitle: 'مساهمة كل قسم في الإيرادات',
          icon: LucideIcons.chartPie,
          accent: AppColors.blueMuted,
          child: SizedBox(
            height: 260,
            child: _CategoryBreakdown(items: state.categorySales),
          ),
        );

        if (!wide) {
          return Column(
            children: [
              trend,
              const SizedBox(height: AppSpacing.md),
              categories,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: trend),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: 3, child: categories),
          ],
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<DailyRevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _ChartEmptyState(
        icon: LucideIcons.chartSpline,
        message: 'لا توجد حركة مبيعات لهذه الفترة',
      );
    }

    final maxValue =
        points.fold<double>(0, (max, point) => math.max(max, point.value));
    final interval = maxValue <= 0 ? 1.0 : _niceInterval(maxValue);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxValue <= 0 ? 1 : maxValue * 1.16,
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.charcoalDark,
              tooltipBorderRadius: BorderRadius.all(Radius.circular(12)),
              getTooltipItems: (spots) => spots
                  .map(
                    (spot) => LineTooltipItem(
                      _formatMoney(spot.y),
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.borderColor.withValues(alpha: .65),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: interval,
                getTitlesWidget: (value, _) => Text(
                  _compactNumber(value),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval:
                    points.length > 8 ? (points.length / 6).ceilToDouble() : 1,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _shortDay(points[index].day),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                points.length,
                (index) => FlSpot(index.toDouble(), points[index].value),
              ),
              isCurved: true,
              curveSmoothness: .28,
              color: AppColors.warmOrange,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: points.length <= 10),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.warmOrange.withValues(alpha: .24),
                    AppColors.warmOrange.withValues(alpha: .01),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _niceInterval(double maxValue) {
    final raw = maxValue / 4;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalized = raw / magnitude;
    final nice = normalized <= 1
        ? 1
        : normalized <= 2
            ? 2
            : normalized <= 5
                ? 5
                : 10;
    return nice * magnitude;
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.items});

  final List<CategorySales> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _ChartEmptyState(
        icon: LucideIcons.chartPie,
        message: 'لا توجد بيانات أقسام لهذه الفترة',
      );
    }

    final visibleItems = items.take(5).toList();
    final total = items.fold<double>(0, (sum, item) => sum + item.revenue);
    final colors = [
      AppColors.warmOrange,
      AppColors.ember,
      AppColors.blueMuted,
      AppColors.successGreen,
      const Color(0xFF8B5CF6),
    ];

    return Column(
      children: [
        for (var index = 0; index < visibleItems.length; index++) ...[
          _CategoryRow(
            item: visibleItems[index],
            total: total,
            color: colors[index % colors.length],
          ),
          if (index != visibleItems.length - 1) const SizedBox(height: 13),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.total,
    required this.color,
  });

  final CategorySales item;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (item.revenue / total).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatMoney(item.revenue),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: color,
            backgroundColor: color.withValues(alpha: .09),
          ),
        ),
      ],
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.items});

  final List<TopItem> items;

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      title: 'الأصناف الأكثر مبيعاً',
      subtitle: 'ترتيب الأصناف حسب الكمية والإيراد المحقق',
      icon: LucideIcons.trophy,
      accent: AppColors.ember,
      child: items.isEmpty
          ? const SizedBox(
              height: 180,
              child: _ChartEmptyState(
                icon: LucideIcons.utensils,
                message: 'ستظهر الأصناف هنا بعد اكتمال المبيعات',
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxQty =
                    items.fold<int>(0, (max, item) => math.max(max, item.qty));
                return Column(
                  children: [
                    if (constraints.maxWidth >= 660)
                      _ProductTableHeader()
                    else
                      const SizedBox.shrink(),
                    for (var index = 0; index < items.length; index++)
                      _ProductRow(
                        rank: index + 1,
                        item: items[index],
                        maxQty: maxQty,
                        compact: constraints.maxWidth < 660,
                        showDivider: index != items.length - 1,
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _ProductTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(width: 42, child: Text('الترتيب', style: style)),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Text('الصنف', style: style)),
          Expanded(flex: 2, child: Text('حصة المبيعات', style: style)),
          SizedBox(width: 80, child: Text('الكمية', style: style)),
          SizedBox(
            width: 110,
            child: Text('الإيراد', textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.rank,
    required this.item,
    required this.maxQty,
    required this.compact,
    required this.showDivider,
  });

  final int rank;
  final TopItem item;
  final int maxQty;
  final bool compact;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1
        ? AppColors.ember
        : rank == 2
            ? AppColors.blueMuted
            : AppColors.textSecondary;
    final progress = maxQty == 0 ? 0.0 : item.qty / maxQty;

    final row = compact
        ? Row(
            children: [
              _RankBadge(rank: rank, color: rankColor),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        color: AppColors.warmOrange,
                        backgroundColor: AppColors.borderColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.qty} طلب',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    _formatMoney(item.revenue),
                    style: const TextStyle(
                      color: AppColors.warmOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          )
        : Row(
            children: [
              SizedBox(
                  width: 42, child: _RankBadge(rank: rank, color: rankColor)),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      color: AppColors.warmOrange,
                      backgroundColor: AppColors.borderColor,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  NumberFormat.decimalPattern('ar').format(item.qty),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  _formatMoney(item.revenue),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.warmOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: AppColors.borderColor))
            : null,
      ),
      child: row,
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.color});

  final int rank;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$rank',
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.grillRed.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.grillRed.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.triangleAlert,
              color: AppColors.grillRed, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'تعذر تحديث بيانات التقارير. حاول مرة أخرى.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => context.read<ReportsCubit>().load(),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1080
                ? 4
                : constraints.maxWidth >= 620
                    ? 2
                    : 1;
            final width =
                (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                    columns;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: List.generate(
                4,
                (_) => SizedBox(
                    width: width, child: const _SkeletonBox(height: 126)),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        const _SkeletonBox(height: 360),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.warmOrange.withValues(alpha: .45),
          ),
        ),
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.charcoalLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.mutedColor, size: 23),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
}

String _formatMoney(double value) =>
    '${NumberFormat('#,##0.00').format(value)} ج.م';

String _compactNumber(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toStringAsFixed(0);
}

String _shortDay(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ? value : DateFormat('d/M').format(parsed);
}
