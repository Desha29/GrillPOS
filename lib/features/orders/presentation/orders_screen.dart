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
                              _showActionSheet(context, order),
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
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.warmOrange,
                  onPrimary: Colors.white,
                  surface: AppColors.charcoalMedium,
                  onSurface: AppColors.cream,
                ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() {
        _dateFilter = 'custom';
        _customStart = range.start;
        _customEnd = range.end;
      });
    }
  }

  void _showActionSheet(BuildContext context, RestaurantOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadius)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'طلب #${order.orderNumber}',
                      style: TextStyle(
                        color: AppColors.cream,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      order.orderType == OrderType.dineIn
                          ? 'طاولة ${order.tableId ?? '?'}'
                          : 'تيك أواي',
                      style: TextStyle(
                          color: AppColors.warmOrange,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(color: AppColors.borderColor),
                ...OrderStatus.values
                    .where((s) => s != OrderStatus.cancelled)
                    .map(
                      (s) => ListTile(
                        leading: Icon(
                          order.status == s
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: order.status == s
                              ? AppColors.warmOrange
                              : AppColors.mutedColor,
                          size: 20,
                        ),
                        title: Text(
                          s.displayName,
                          style: TextStyle(
                            color: order.status == s
                                ? AppColors.warmOrange
                                : AppColors.cream,
                            fontWeight: order.status == s
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          context
                              .read<OrdersCubit>()
                              .updateStatus(order.id, s);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                Divider(color: AppColors.borderColor),
                ListTile(
                  leading:
                      Icon(Icons.check_circle, color: AppColors.successGreen),
                  title: Text('تم الدفع وإرشاد الطلب للأرشيف',
                      style: TextStyle(
                          color: AppColors.successGreen,
                          fontWeight: FontWeight.bold)),
                  onTap: () {
                    context.read<OrdersCubit>().markPaid(order.id);
                    Navigator.of(context).pop();
                  },
                ),
                if (order.status != OrderStatus.cancelled) ...[
                  Divider(color: AppColors.borderColor),
                  ListTile(
                    leading: Icon(Icons.cancel, color: AppColors.grillRed),
                    title: Text('إلغاء الطلب',
                        style: TextStyle(
                            color: AppColors.grillRed,
                            fontWeight: FontWeight.bold)),
                    onTap: () {
                      context
                          .read<OrdersCubit>()
                          .updateStatus(order.id, OrderStatus.cancelled);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ],
            ),
          ),
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
