import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
    required this.isManager,
  });

  final void Function(String id) onCardTap;
  final bool isManager;

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome>
    with SingleTickerProviderStateMixin {
  final double _revenue = 0;
  final int _ordersCount = 0;
  final double _avgOrder = 0;
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

    // Listen to streams for real-time updates
    try {
      final ordersRepo = getIt<OrdersRepository>();
      _ordersSub = ordersRepo.ordersStream.listen((_) => _loadData());
    } catch (_) {}

    try {
      final tablesRepo = getIt<TablesRepository>();
      _tablesSub = tablesRepo.tablesStream.listen((_) => _loadData());
    } catch (_) {}
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

      // Load tables
      final tables = await tablesRepo.getTables();
      final occupiedCount =
          tables.where((t) => t.status == TableStatus.occupied).length;

      // Load recent orders (last 5)
      final allOrders = await ordersRepo.getOrders(onlyActive: false);
      final recent = allOrders.take(5).toList();

      if (!mounted) return;
      setState(() {
        _occupiedTables = occupiedCount;
        _totalTables = tables.length;
        _recentOrders = recent;
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
      child: Column(
        children: [
          // ─── Fixed Header + Stat Cards (no scrolling) ───
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: ScreenHeader(
              title: 'الرئيسية',
              subtitle: 'نظرة عامة على الوردية الحالية',
              icon: LucideIcons.layoutDashboard,
              trailingIcon: Icons.refresh,
              onTrailingPressed: _loadData,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _isLoading
                ? _buildSkeletonCards(columns)
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cards.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio:
                          width > 1400 ? 2.2 : 1.8,
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
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ─── Scrollable Recent Orders ───
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(
                      AppSpacing.cardRadius),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.warmOrange
                                .withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: Icon(
                            LucideIcons.clipboardList,
                            color: AppColors.warmOrange,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'آخر الطلبات',
                          style: TextStyle(
                            color: AppColors.cream,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_recentOrders.isNotEmpty)
                          TextButton.icon(
                            onPressed: () =>
                                widget.onCardTap('orders'),
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
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child:
                                  CircularProgressIndicator(
                                color: AppColors.warmOrange,
                                strokeWidth: 2,
                              ),
                            )
                          : _recentOrders.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                    children: [
                                      Icon(
                                        LucideIcons
                                            .clipboardList,
                                        size: 48,
                                        color: AppColors
                                            .mutedColor
                                            .withOpacity(0.3),
                                      ),
                                      const SizedBox(
                                          height: 12),
                                      Text(
                                        'لا توجد طلبات بعد',
                                        style: TextStyle(
                                          color: AppColors
                                              .creamMuted,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(
                                          height: 4),
                                      Text(
                                        'ستظهر الطلبات الجديدة هنا تلقائياً',
                                        style: TextStyle(
                                          color: AppColors
                                              .mutedColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount:
                                      _recentOrders.length,
                                  itemBuilder: (_, i) {
                                    return _AnimatedCardWrapper(
                                      index: i,
                                      controller:
                                          _animController,
                                      child: OrderCard(
                                        order:
                                            _recentOrders[i],
                                        onTap: () => widget
                                            .onCardTap(
                                                'orders'),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
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
