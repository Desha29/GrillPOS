import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
          // ─── Pinned Header + Stat Cards ───
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

          // ─── Bottom Sections (Recent Orders & Quick Actions) ───
          // ─── Bottom Sections (Recent Orders & Quick Actions) ───
          Expanded(
            child: Padding(
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
                          child: _buildRecentOrdersSection(fillHeight: true),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        SizedBox(
                          width: 300, // Fixed width for quick actions on wide screen
                          child: _buildQuickActionsSection(),
                        ),
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    child: Column(
                      children: [
                        _buildQuickActionsSection(horizontal: true),
                        const SizedBox(height: AppSpacing.lg),
                        _buildRecentOrdersSection(fillHeight: false),
                      ],
                    ),
                  );
                },
              ),
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderColor),
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

  Widget _buildRecentOrdersSection({bool fillHeight = false}) {
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
        if (fillHeight)
          Expanded(
            child: _buildRecentOrdersList(),
          )
        else
          _buildRecentOrdersList(),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: content,
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
      physics: const BouncingScrollPhysics(),
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
              color: _isHovered ? AppColors.charcoalLight : AppColors.charcoalMedium,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered ? widget.color : AppColors.borderColor,
                width: _isHovered ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered ? widget.color.withOpacity(0.15) : Colors.black.withOpacity(0.05),
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
