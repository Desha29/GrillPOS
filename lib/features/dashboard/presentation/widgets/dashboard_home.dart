import 'package:flutter/material.dart';
import 'package:grill_pos/core/components/screen_header.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/components/dashboard_stat_card.dart';
import '../../../../core/components/order_card.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../orders/data/orders_repository.dart';
import '../../../orders/data/order_models.dart';
import '../../../reports/data/reports_repository.dart';
import '../../../tables/data/tables_repository.dart';
import '../../../tables/data/table_models.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({
    super.key,
    required this.onCardTap,
    required this.isManager,
  });

  final void Function(String id) onCardTap;
  final bool isManager;

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  bool _loading = true;
  double _revenue = 0;
  int _ordersCount = 0;
  double _avgOrder = 0;
  int _occupiedTables = 0;
  int _totalTables = 0;
  List<RestaurantOrder> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final reportsRepo = getIt<ReportsRepository>();
      final ordersRepo = getIt<OrdersRepository>();
      final tablesRepo = getIt<TablesRepository>();

      // Load today's summary
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final summary = await reportsRepo.getSummary(from: todayStart);

      // Load tables
      final tables = await tablesRepo.getTables();
      final occupiedCount =
          tables.where((t) => t.status == TableStatus.occupied).length;

      // Load recent orders (last 5)
      final allOrders = await ordersRepo.getOrders(onlyActive: false);
      final recent = allOrders.take(5).toList();

      if (!mounted) return;
      setState(() {
        _revenue = summary.revenue;
        _ordersCount = summary.ordersCount;
        _avgOrder = summary.avgOrder;
        _occupiedTables = occupiedCount;
        _totalTables = tables.length;
        _recentOrders = recent;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final occupancyPct =
        _totalTables > 0 ? (_occupiedTables / _totalTables * 100) : 0.0;

    final cards = [
      _StatData(
        id: 'pos',
        title: "إيرادات اليوم",
        value: '${_revenue.toStringAsFixed(2)} ج.م',
        icon: Icons.attach_money,
        color: AppColors.warmOrange,
        trend: _ordersCount > 0 ? 'نشط' : 'لا مبيعات بعد',
        positive: _ordersCount > 0,
      ),
      _StatData(
        id: 'orders',
        title: 'عدد الطلبات',
        value: '$_ordersCount',
        icon: Icons.receipt_long,
        color: AppColors.ember,
        trend: 'اليوم',
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

    final width = MediaQuery.of(context).size.width;
    final columns = width > 1400 ? 4 : 2;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.charcoalDark, AppColors.charcoalMedium],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.warmOrange,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ScreenHeader(
              title: 'الرئيسية',
              subtitle: 'نظرة عامة على أداء مطعم GrillPOS',
              icon: LucideIcons.layoutDashboard,
              trailingIcon: Icons.refresh,
              onTrailingPressed: _loadData,
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.8,
              ),
              itemBuilder: (_, i) {
                final c = cards[i];
                return GestureDetector(
                  onTap: () => widget.onCardTap(c.id),
                  child: DashboardStatCard(
                    title: c.title,
                    value: c.value,
                    icon: c.icon,
                    color: c.color,
                    trend: c.trend,
                    isPositiveTrend: c.positive,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'آخر الطلبات',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_recentOrders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                        child: Text(
                          'لا توجد طلبات بعد. ستظهر الطلبات الجديدة هنا عند بدء التشغيل.',
                          style: TextStyle(color: AppColors.creamMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...(_recentOrders.map(
                      (order) => OrderCard(
                        order: order,
                        onTap: () => widget.onCardTap('orders'),
                      ),
                    )),
                ],
              ),
            ),
          ],
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
