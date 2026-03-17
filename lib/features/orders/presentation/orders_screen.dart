import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/components/order_card.dart';
import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../data/order_models.dart';
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

class _OrdersView extends StatelessWidget {
  const _OrdersView();

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
              const SizedBox(height: AppSpacing.md),
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
                      return Center(child: CircularProgressIndicator(color: AppColors.warmOrange));
                    }

                    if (state.error != null &&
                        state.activeOrders.isEmpty &&
                        state.historyOrders.isEmpty) {
                      return Center(
                        child: Text(state.error!,
                            style: TextStyle(color: AppColors.grillRed)),
                      );
                    }

                    return TabBarView(
                      children: [
                        _OrdersList(
                          orders: state.activeOrders,
                          emptyText: 'لا توجد طلبات نشطة حالياً',
                          emptyIcon: Icons.receipt_long_outlined,
                          onTap: (order) => _showActionSheet(context, order),
                        ),
                        _OrdersList(
                          orders: state.historyOrders,
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

  void _showActionSheet(BuildContext context, RestaurantOrder order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadius)),
      ),
      builder: (_) => Padding(
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
                  order.orderType == OrderType.dineIn ? 'طاولة ${order.tableId ?? '?'}' : 'تيك أواي',
                  style: TextStyle(color: AppColors.warmOrange, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: AppColors.borderColor),
            ...OrderStatus.values.where((s) => s != OrderStatus.cancelled).map(
                  (s) => ListTile(
                    leading: Icon(
                      order.status == s ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: order.status == s ? AppColors.warmOrange : AppColors.mutedColor,
                      size: 20,
                    ),
                    title: Text(
                      s.displayName,
                      style: TextStyle(
                        color: order.status == s ? AppColors.warmOrange : AppColors.cream,
                        fontWeight: order.status == s ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      context.read<OrdersCubit>().updateStatus(order.id, s);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
            Divider(color: AppColors.borderColor),
            ListTile(
              leading: Icon(Icons.check_circle, color: AppColors.successGreen),
              title: Text('تم الدفع وإرشاد الطلب للأرشيف',
                  style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold)),
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
                    style: TextStyle(color: AppColors.grillRed, fontWeight: FontWeight.bold)),
                onTap: () {
                  context.read<OrdersCubit>().updateStatus(order.id, OrderStatus.cancelled);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ],
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
            Icon(emptyIcon, size: 48, color: AppColors.mutedColor.withOpacity(0.4)),
            const SizedBox(height: AppSpacing.sm),
            Text(emptyText,
                style: TextStyle(color: AppColors.creamMuted)),
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
