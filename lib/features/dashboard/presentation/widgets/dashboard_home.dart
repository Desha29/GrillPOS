import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../auth/presentation/cubit/user_cubit.dart';
import '../../../../core/components/dashboard_stat_card.dart';
import '../../../../core/components/order_card.dart';
import '../../../../core/components/screen_header.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../orders/data/orders_repository.dart';
import '../../../orders/data/order_models.dart';
import '../../../tables/data/tables_repository.dart';
import '../../../tables/data/table_models.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({
    super.key,
    required this.onCardTap,
    required this.onOrderTap,
    required this.isManager,
  });

  final void Function(String id) onCardTap;
  final void Function(RestaurantOrder order) onOrderTap;
  final bool isManager;

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome>
    with SingleTickerProviderStateMixin {
  double _revenue = 0;
  int _ordersCount = 0;
  double _avgOrder = 0;
  int _occupiedTables = 0;
  int _totalTables = 0;
  List<RestaurantOrder> _recentOrders = [];
  bool _isLoading = true;

  StreamSubscription? _ordersSub;
  StreamSubscription? _tablesSub;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadData();

    // Listen to repo streams for immediate updates
    final ordersRepo = getIt<OrdersRepository>();
    final tablesRepo = getIt<TablesRepository>();

    _ordersSub = ordersRepo.ordersStream.listen((_) {
      _loadData();
    });
    
    _tablesSub = tablesRepo.tablesStream.listen((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _tablesSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    try {
      final ordersRepo = getIt<OrdersRepository>();
      final tablesRepo = getIt<TablesRepository>();

      // 1. Load tables
      final tables = await tablesRepo.getTables();
      final occupiedCount = tables.where((t) => t.status == TableStatus.occupied).length;

      // 2. Load today's orders for stats
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      
      final allOrders = await ordersRepo.getOrders(onlyActive: false);
      
      final todayOrders = allOrders.where((o) => o.createdAt.isAfter(todayStart)).toList();
      final completedToday = todayOrders.where((o) => o.status == OrderStatus.completed).toList();
      
      double totalRevenue = 0;
      for (var o in completedToday) {
        totalRevenue += o.totalAmount;
      }

      // 3. Update state
      if (!mounted) return;
      setState(() {
        _revenue = totalRevenue;
        _ordersCount = todayOrders.length;
        _avgOrder = _ordersCount > 0 ? (totalRevenue / _ordersCount) : 0;
        _occupiedTables = occupiedCount;
        _totalTables = tables.length;
        _recentOrders = allOrders.take(10).toList();
        _isLoading = false;
      });

      _animController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final occupancyPct =
        _totalTables > 0 ? (_occupiedTables / _totalTables * 100) : 0.0;

    final cards = [
      _StatData(
        id: 'pos',
        title: "إيرادات الوردية",
        value: '${_revenue.toStringAsFixed(2)} ج.م',
        icon: Icons.attach_money,
        color: AppColors.warmOrange,
        trend: _ordersCount > 0 ? 'نشط' : 'لا مبيعات بعد',
        positive: _ordersCount > 0,
      ),
      _StatData(
        id: 'orders',
        title: 'طلبات الوردية',
        value: '$_ordersCount',
        icon: Icons.receipt_long,
        color: AppColors.ember,
        trend: 'الوردية الحالية',
        positive: true,
      ),
      _StatData(
        id: 'reports',
        title: 'متوسط الطلب',
        value: '${_avgOrder.toStringAsFixed(2)} ج.م',
        icon: Icons.analytics,
        color: AppColors.successGreen,
        trend: 'لكل فاتورة',
        positive: true,
      ),
      _StatData(
        id: 'tables',
        title: 'إشغال الطاولات',
        value: '${occupancyPct.toStringAsFixed(0)}%',
        icon: Icons.table_restaurant,
        color: AppColors.grillRed,
        trend: '$_occupiedTables / $_totalTables',
        positive: true,
      ),
    ];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final curUser = getIt<UserCubit>().currentUser;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF8F9FC),
                  Color(0xFFEEF0F5),
                  Color(0xFFE8EAF0),
                ],
              ),
        color: isDark ? const Color(0xFF0D0E12) : null,
        image: isDark
            ? DecorationImage(
                image: const AssetImage('assets/images/grillpos/login_bg.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.8),
                  BlendMode.srcOver,
                ),
              )
            : null,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: FoodPatternPainter(
                color: theme.colorScheme.onSurface
                    .withOpacity(isDark ? 0.012 : 0.022),
              ),
            ),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Pinned Header ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                  child: ScreenHeader(
                    title: 'الرئيسية',
                    subtitle: 'نظرة عامة على الوردية الحالية',
                    icon: LucideIcons.layoutDashboard,
                    trailingWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Refresh button
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark.withOpacity(0.6)
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderColor.withOpacity(0.3)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _loadData,
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(Icons.refresh, color: AppColors.cream, size: 20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        // Notification Bell with Badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.surfaceDark.withOpacity(0.6)
                                    : Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.borderColor.withOpacity(0.3)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'لديك $_ordersCount طلبات نشطة في هذه الوردية',
                                          style: const TextStyle(fontFamily: 'Cairo'),
                                        ),
                                        backgroundColor: AppColors.warmOrange,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(LucideIcons.bell, color: AppColors.cream, size: 20),
                                  ),
                                ),
                              ),
                            ),
                            if (_recentOrders.any((o) => o.status == OrderStatus.pending))
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.grillRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        // Profile Info Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark.withOpacity(0.6)
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderColor.withOpacity(0.3)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: widget.isManager
                                    ? AppColors.warmOrange.withOpacity(0.2)
                                    : AppColors.blueMuted.withOpacity(0.2),
                                child: Text(
                                  curUser.name.isNotEmpty ? curUser.name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: widget.isManager ? AppColors.warmOrange : AppColors.blueMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                curUser.name,
                                style: TextStyle(
                                  color: AppColors.cream,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.creamMuted,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ─── Stat Cards ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final columns = w > 1100
                          ? 4
                          : w > 600
                              ? 2
                              : 1;
                      final aspectRatio = w > 1100
                          ? 2.2
                          : w > 600
                              ? 2.0
                              : 3.5;
                      if (_isLoading) return _buildSkeletonCards(columns);
                      return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cards.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                            childAspectRatio: aspectRatio,
                          ),
                          itemBuilder: (_, i) {
                            final c = cards[i];
                            return _AnimatedCardWrapper(
                              index: i,
                              controller: _animController,
                              child: GestureDetector(
                                onTap: () => widget.onCardTap(c.id),
                                child: DashboardStatCard(
                                  title: c.title,
                                  value: c.value,
                                  icon: c.icon,
                                  color: c.color,
                                  trend: c.trend,
                                  isPositiveTrend: c.positive,
                                ),
                              ),
                            );
                          });
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ─── Charts Section ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _buildChartsSection(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ─── Bottom Sections (Recent Orders & Quick Actions) ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final isWide = w > 900;

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildRecentOrdersSection(),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            SizedBox(
                              width: 300,
                              child: _buildQuickActionsSection(),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _buildQuickActionsSection(horizontal: true),
                          const SizedBox(height: AppSpacing.lg),
                          _buildRecentOrdersSection(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection({bool horizontal = false}) {
    final quickActions = [
      _QuickAction(
        id: 'pos',
        title: 'طلب جديد',
        icon: LucideIcons.plusCircle,
        color: AppColors.warmOrange,
      ),
      _QuickAction(
        id: 'tables',
        title: 'الطاولات',
        icon: LucideIcons.grid,
        color: AppColors.ember,
      ),
      _QuickAction(
        id: 'orders',
        title: 'الطلبات',
        icon: LucideIcons.receipt,
        color: AppColors.flameLight,
      ),
      _QuickAction(
        id: 'menu',
        title: 'المنيو',
        icon: LucideIcons.bookOpen,
        color: AppColors.successGreen,
      ),
      _QuickAction(
        id: 'reports',
        title: 'التقرير',
        icon: LucideIcons.barChart3,
        color: AppColors.grillRed,
      ),
      _QuickAction(
        id: 'users',
        title: 'الموظفين',
        icon: LucideIcons.users,
        color: AppColors.blueMuted,
      ),
    ];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark.withOpacity(0.65) : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isDark ? AppColors.borderColor.withOpacity(0.4) : const Color(0xFFE2E8F0),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      LucideIcons.zap,
                      color: AppColors.successGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'عمليات سريعة',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _buildQuickActionsGrid(quickActions, horizontal: horizontal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(List<_QuickAction> quickActions, {bool horizontal = false}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: quickActions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: horizontal ? (quickActions.length <= 4 ? 4 : 6) : 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: horizontal ? 1.8 : 1.3,
      ),
      itemBuilder: (_, i) {
        final action = quickActions[i];
        return _QuickActionCard(
          title: action.title,
          icon: action.icon,
          color: action.color,
          onTap: () => widget.onCardTap(action.id),
        );
      },
    );
  }

  List<FlSpot> _getSalesSpots() {
    final hourlyRevenue = <int, double>{
      9: 0.0,
      12: 0.0,
      15: 0.0,
      18: 0.0,
      21: 0.0,
      0: 0.0,
      3: 0.0,
    };

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    for (var order in _recentOrders) {
      if (order.status == OrderStatus.completed && order.createdAt.isAfter(todayStart)) {
        final hour = order.createdAt.hour;
        int bucket = 9;
        final sortedKeys = hourlyRevenue.keys.toList()..sort();
        for (var b in sortedKeys) {
          if (hour >= b && hour < b + 3) {
            bucket = b;
            break;
          }
        }
        hourlyRevenue[bucket] = (hourlyRevenue[bucket] ?? 0.0) + order.totalAmount;
      }
    }

    bool allZero = hourlyRevenue.values.every((v) => v == 0);
    if (allZero) {
      return const [
        FlSpot(0, 120),
        FlSpot(1, 280),
        FlSpot(2, 450),
        FlSpot(3, 850),
        FlSpot(4, 600),
        FlSpot(5, 1200),
        FlSpot(6, 400),
      ];
    }

    final spots = <FlSpot>[];
    final keys = hourlyRevenue.keys.toList()..sort();
    for (int i = 0; i < keys.length; i++) {
      spots.add(FlSpot(i.toDouble(), hourlyRevenue[keys[i]]!));
    }
    return spots;
  }

  Widget _buildChartsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isWide = w > 900;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildSalesLineChart(),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                flex: 2,
                child: _buildOrderTypePieChart(),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildSalesLineChart(),
            const SizedBox(height: AppSpacing.lg),
            _buildOrderTypePieChart(),
          ],
        );
      },
    );
  }

  Widget _buildSalesLineChart() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 320,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark.withOpacity(0.65) : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isDark ? AppColors.borderColor.withOpacity(0.4) : const Color(0xFFE2E8F0),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إحصائيات المبيعات اليومية',
                        style: TextStyle(
                          color: AppColors.cream,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'حجم المبيعات لكل ساعة اليوم',
                        style: TextStyle(
                          color: AppColors.creamMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warmOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'مباشر',
                      style: TextStyle(
                        color: AppColors.warmOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: AppColors.borderColor.withOpacity(0.15),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            const hours = ['09:00', '12:00', '15:00', '18:00', '21:00', '00:00', '03:00'];
                            if (value.toInt() >= 0 && value.toInt() < hours.length) {
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  hours[value.toInt()],
                                  style: TextStyle(
                                    color: AppColors.creamMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 300,
                          reservedSize: 55,
                          getTitlesWidget: (value, meta) {
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                '${value.toInt()} ج.م',
                                style: TextStyle(
                                  color: AppColors.creamMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: 1500,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _getSalesSpots(),
                        isCurved: true,
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.warmOrange,
                            AppColors.ember,
                          ],
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.warmOrange.withOpacity(0.25),
                              AppColors.ember.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTypePieChart() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int dineIn = 0;
    int takeaway = 0;
    int delivery = 0;
    for (var o in _recentOrders) {
      switch (o.orderType) {
        case OrderType.dineIn:
          dineIn++;
          break;
        case OrderType.takeaway:
          takeaway++;
          break;
        case OrderType.delivery:
          delivery++;
          break;
      }
    }
    if (dineIn == 0 && takeaway == 0 && delivery == 0) {
      dineIn = 5;
      takeaway = 3;
      delivery = 2;
    }
    final total = dineIn + takeaway + delivery;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 320,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark.withOpacity(0.65) : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isDark ? AppColors.borderColor.withOpacity(0.4) : const Color(0xFFE2E8F0),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'توزيع أنواع الطلبات',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'نسبة المبيعات حسب نوع الطلب',
                style: TextStyle(
                  color: AppColors.creamMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 35,
                          sections: [
                            PieChartSectionData(
                              color: AppColors.warmOrange,
                              value: dineIn.toDouble(),
                              title: '${(dineIn / total * 100).toStringAsFixed(0)}%',
                              radius: 35,
                              titleStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              color: AppColors.ember,
                              value: takeaway.toDouble(),
                              title: '${(takeaway / total * 100).toStringAsFixed(0)}%',
                              radius: 35,
                              titleStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              color: AppColors.blueMuted,
                              value: delivery.toDouble(),
                              title: '${(delivery / total * 100).toStringAsFixed(0)}%',
                              radius: 35,
                              titleStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem('داخلي', AppColors.warmOrange, dineIn),
                        const SizedBox(height: 8),
                        _buildLegendItem('تيك أواي', AppColors.ember, takeaway),
                        const SizedBox(height: 8),
                        _buildLegendItem('توصيل', AppColors.blueMuted, delivery),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$title ($count)',
          style: TextStyle(
            color: AppColors.cream,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrdersSection() {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warmOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                LucideIcons.clipboardList,
                color: AppColors.warmOrange,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'آخر الطلبات',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_recentOrders.isNotEmpty)
              TextButton.icon(
                onPressed: () => widget.onCardTap('orders'),
                icon: Icon(
                  LucideIcons.arrowLeft,
                  size: 14,
                  color: AppColors.warmOrange,
                ),
                label: Text(
                  'عرض الكل',
                  style: TextStyle(
                    color: AppColors.warmOrange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildRecentOrdersList(),
      ],
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark.withOpacity(0.65) : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isDark ? AppColors.borderColor.withOpacity(0.4) : const Color(0xFFE2E8F0),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildRecentOrdersList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: AppColors.warmOrange),
        ),
      );
    }

    if (_recentOrders.isEmpty) {
      return _buildEmptyOrders();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _recentOrders.length,
      itemBuilder: (_, i) {
        return _AnimatedCardWrapper(
          index: i,
          controller: _animController,
          child: OrderCard(
            order: _recentOrders[i],
            onTap: () => widget.onOrderTap(_recentOrders[i]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.mutedColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.clipboardList,
                size: 48,
                color: AppColors.mutedColor.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد طلبات بعد',
              style: TextStyle(
                color: AppColors.creamMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ستظهر الطلبات الجديدة هنا تلقائياً عند البدء في استقبال الزبائن',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCards(int columns) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.8,
      ),
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppColors.warmOrange.withOpacity(0.3),
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isDark
                  ? (_isHovered
                      ? AppColors.charcoalLight.withOpacity(0.8)
                      : AppColors.charcoalMedium.withOpacity(0.5))
                  : (_isHovered
                      ? widget.color.withOpacity(0.08)
                      : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered ? widget.color : AppColors.borderColor.withOpacity(0.5),
                width: _isHovered ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? (_isHovered ? widget.color.withOpacity(0.15) : Colors.black.withOpacity(0.05))
                      : (_isHovered ? widget.color.withOpacity(0.12) : Colors.black.withOpacity(0.02)),
                  blurRadius: _isHovered ? 12 : 4,
                  offset: Offset(0, _isHovered ? 4 : 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isHovered ? widget.color.withOpacity(0.2) : widget.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.cream,
                    fontSize: 12,
                    fontWeight: _isHovered ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final String id;
  final String title;
  final IconData icon;
  final Color color;

  const _QuickAction({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
  });
}

class _AnimatedCardWrapper extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _AnimatedCardWrapper({
    required this.index,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final delay = index * 0.15;
    final begin = delay.clamp(0.0, 0.7);
    final end = (begin + 0.3).clamp(0.0, 1.0);

    final opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(begin, end, curve: Curves.easeOut),
      ),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(begin, end, curve: Curves.easeOut),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Opacity(
        opacity: opacity.value,
        child: Transform.translate(
          offset: Offset(0, slide.value.dy * 30),
          child: child,
        ),
      ),
    );
  }
}

class _StatData {
  final String id;
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;
  final bool positive;

  const _StatData({
    required this.id,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
    required this.positive,
  });
}

class FoodPatternPainter extends CustomPainter {
  final Color color;

  FoodPatternPainter({required this.color});

  static const List<IconData> _foodIcons = [
    Icons.lunch_dining_rounded,
    Icons.local_drink_rounded,
    Icons.local_pizza_rounded,
    Icons.local_fire_department_rounded,
    Icons.coffee_rounded,
    Icons.restaurant_rounded,
    Icons.icecream_rounded,
    Icons.cake_rounded,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: color,
      fontSize: 32,
      fontFamily: 'MaterialIcons',
    );

    const double stepX = 120.0;
    const double stepY = 120.0;
    int index = 0;

    for (double y = 40; y < size.height; y += stepY) {
      // Offset alternate rows for a staggered brick-like pattern
      final double startX = (index % 2 == 0) ? 40.0 : 100.0;
      for (double x = startX; x < size.width; x += stepX) {
        final icon =
            _foodIcons[(index + (x / stepX).round()) % _foodIcons.length];

        final textPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: textStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height / 2),
        );
      }
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
