import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/components/order_card.dart';
import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../data/order_models.dart';
import '../data/orders_repository.dart';
import '../../../core/components/custom_date_range_picker.dart';
import 'cubit/orders_cubit.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OrdersCubit>()..loadOrders(),
      child: const _OrdersView(),
    );
  }
}

class _OrdersView extends StatefulWidget {
  const _OrdersView();

  @override
  State<_OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<_OrdersView> {
  StreamSubscription? _ordersSub;
  String _dateFilter = 'today'; // today, week, month, year, all
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    // Listen to real-time order changes
    try {
      final ordersRepo = getIt<OrdersRepository>();
      _ordersSub = ordersRepo.ordersStream.listen((_) {
        if (mounted) {
          context.read<OrdersCubit>().loadOrders();
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    super.dispose();
  }

  List<RestaurantOrder> _filterByDate(List<RestaurantOrder> orders) {
    final now = DateTime.now();
    DateTime startDate;

    switch (_dateFilter) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
      case 'custom':
        if (_customStart != null) {
          return orders.where((o) {
            final d = o.createdAt;
            final after = d.isAfter(_customStart!) ||
                d.isAtSameMomentAs(_customStart!);
            final before = _customEnd == null
                ? true
                : d.isBefore(_customEnd!.add(const Duration(days: 1)));
            return after && before;
          }).toList();
        }
        return orders;
      default:
        return orders;
    }

    return orders
        .where((o) =>
            o.createdAt.isAfter(startDate) ||
            o.createdAt.isAtSameMomentAs(startDate))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.charcoalDark,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: ScreenHeader(
                  title: 'الطلبات',
                  subtitle: 'إدارة طلبات المطعم ومتابعة التحضير',
                  icon: Icons.receipt_long,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ─── Date Filter Bar ───
              _buildDateFilterBar(),

              const SizedBox(height: AppSpacing.sm),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: AppColors.warmOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.mutedColor,
                  dividerColor: Colors.transparent,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  padding: const EdgeInsets.all(4),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('الطلبات النشطة'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 18),
                          SizedBox(width: 8),
                          Text('سجل الطلبات'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: BlocBuilder<OrdersCubit, OrdersState>(
                  builder: (context, state) {
                    if (state.loading &&
                        state.activeOrders.isEmpty &&
                        state.historyOrders.isEmpty) {
                      return Center(
                          child: CircularProgressIndicator(
                              color: AppColors.warmOrange));
                    }

                    if (state.error != null &&
                        state.activeOrders.isEmpty &&
                        state.historyOrders.isEmpty) {
                      return Center(
                        child: Text(state.error!,
                            style: TextStyle(color: AppColors.grillRed)),
                      );
                    }

                    final filteredActive =
                        _filterByDate(state.activeOrders);
                    final filteredHistory =
                        _filterByDate(state.historyOrders);

                    return TabBarView(
                      children: [
                        _OrdersList(
                          orders: filteredActive,
                          emptyText: 'لا توجد طلبات نشطة حالياً',
                          emptyIcon: Icons.receipt_long_outlined,
                          onTap: (order) =>
                              _showActionDialog(context, order),
                        ),
                        _OrdersList(
                          orders: filteredHistory,
                          emptyText: 'لا يوجد سجل للطلبات حتى الآن',
                          emptyIcon: Icons.history,
                          onTap: (_) {},
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterBar() {
    final filters = [
      {'id': 'today', 'label': 'اليوم', 'icon': LucideIcons.calendar},
      {'id': 'week', 'label': 'أسبوع', 'icon': LucideIcons.calendarDays},
      {'id': 'month', 'label': 'شهر', 'icon': LucideIcons.calendarRange},
      {'id': 'year', 'label': 'سنة', 'icon': LucideIcons.calendarCheck},
      {'id': 'all', 'label': 'الكل', 'icon': LucideIcons.infinity},
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...filters.map((f) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _DateFilterChip(
                  label: f['label'] as String,
                  icon: f['icon'] as IconData,
                  isSelected: _dateFilter == f['id'],
                  onTap: () =>
                      setState(() => _dateFilter = f['id'] as String),
                ),
              )),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _DateFilterChip(
              label: 'تاريخ محدد',
              icon: LucideIcons.calendarSearch,
              isSelected: _dateFilter == 'custom',
              onTap: () => _pickDateRange(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final range = await CustomDateRangePicker.show(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (range != null) {
      setState(() {
        _dateFilter = 'custom';
        _customStart = range.start;
        _customEnd = range.end;
      });
    }
  }

  void _showActionDialog(BuildContext context, RestaurantOrder order) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إدارة الطلب #${order.orderNumber}',
                        style: TextStyle(
                          color: AppColors.cream,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.orderType == OrderType.dineIn
                            ? 'طاولة ${order.tableId ?? '?'}'
                            : 'تيك أواي / توصيل',
                        style: TextStyle(color: AppColors.warmOrange, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: Icon(Icons.close, color: AppColors.mutedColor),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'تحديث حالة الطلب',
                style: TextStyle(color: AppColors.mutedColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: OrderStatus.values
                    .where((s) => s != OrderStatus.cancelled)
                    .map((s) {
                  final isSelected = order.status == s;
                  return _StatusActionChip(
                    label: s.displayName,
                    isSelected: isSelected,
                    onTap: () {
                      context.read<OrdersCubit>().updateStatus(order.id, s);
                      Navigator.pop(dialogContext);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Divider(color: AppColors.borderColor),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DialogActionBtn(
                      label: 'تم الدفع والأرشفة',
                      icon: LucideIcons.checkCheck,
                      color: AppColors.successGreen,
                      onTap: () {
                        context.read<OrdersCubit>().markPaid(order.id);
                        Navigator.pop(dialogContext);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogActionBtn(
                      label: 'إلغاء الطلب',
                      icon: LucideIcons.xCircle,
                      color: AppColors.grillRed,
                      onTap: () {
                        context.read<OrdersCubit>().updateStatus(order.id, OrderStatus.cancelled);
                        Navigator.pop(dialogContext);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusActionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusActionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.warmOrange : AppColors.charcoalMedium,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.warmOrange : AppColors.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.cream,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DialogActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DialogActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateFilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.warmOrange.withOpacity(0.15)
                : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.warmOrange.withOpacity(0.5)
                  : AppColors.borderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? AppColors.warmOrange : AppColors.mutedColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color:
                      isSelected ? AppColors.warmOrange : AppColors.creamMuted,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<RestaurantOrder> orders;
  final String emptyText;
  final IconData emptyIcon;
  final ValueChanged<RestaurantOrder> onTap;

  const _OrdersList({
    required this.orders,
    required this.emptyText,
    required this.emptyIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon,
                size: 48, color: AppColors.mutedColor.withOpacity(0.4)),
            const SizedBox(height: AppSpacing.sm),
            Text(emptyText, style: TextStyle(color: AppColors.creamMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: orders.length,
      itemBuilder: (_, i) {
        final order = orders[i];
        return OrderCard(order: order, onTap: () => onTap(order));
      },
    );
  }
}
