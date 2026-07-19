import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/components/custom_date_range_picker.dart';
import '../../../core/components/order_card.dart';
import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/functions/messege.dart';
import '../../../core/security/permission_guard.dart';
import '../../auth/presentation/cubit/user_cubit.dart';
import '../data/order_models.dart';
import '../data/orders_repository.dart';
import 'cubit/orders_cubit.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OrdersCubit>()..loadOrders(),
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: _OrdersView(),
      ),
    );
  }
}

class _OrdersView extends StatefulWidget {
  const _OrdersView();

  @override
  State<_OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<_OrdersView> {
  final _searchController = TextEditingController();
  StreamSubscription<void>? _ordersSubscription;
  String _dateFilter = 'today';
  DateTime? _customStart;
  DateTime? _customEnd;
  String _query = '';
  int _tabIndex = 0;
  OrderStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    try {
      _ordersSubscription = getIt<OrdersRepository>().ordersStream.listen((_) {
        if (mounted) context.read<OrdersCubit>().loadOrders();
      });
    } catch (_) {
      // The stream is optional in tests and lightweight local deployments.
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<RestaurantOrder> _filterByDate(List<RestaurantOrder> orders) {
    if (_dateFilter == 'all') return orders;
    final now = DateTime.now();
    late final DateTime startDate;

    switch (_dateFilter) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
      case 'week':
        final start = now.subtract(const Duration(days: 6));
        startDate = DateTime(start.year, start.month, start.day);
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
      case 'year':
        startDate = DateTime(now.year, 1, 1);
      case 'custom':
        final start = _customStart;
        if (start == null) return orders;
        final end = _customEnd;
        return orders.where((order) {
          final isAfterStart = !order.createdAt.isBefore(start);
          final isBeforeEnd = end == null ||
              order.createdAt.isBefore(end.add(const Duration(days: 1)));
          return isAfterStart && isBeforeEnd;
        }).toList();
      default:
        return orders;
    }

    return orders
        .where((order) => !order.createdAt.isBefore(startDate))
        .toList();
  }

  List<RestaurantOrder> _filterByQuery(List<RestaurantOrder> orders) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return orders;
    return orders.where((order) {
      final searchable = <String?>[
        order.orderNumber,
        order.tableId,
        order.notes,
        order.orderType.displayName,
        order.status.displayName,
        ...order.items.map((item) => item.itemName),
      ].whereType<String>().join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  List<RestaurantOrder> _applyStatusFilter(List<RestaurantOrder> orders) {
    if (_statusFilter == null) return orders;
    return orders.where((order) => order.status == _statusFilter).toList();
  }

  Future<void> _pickDateRange() async {
    final range = await CustomDateRangePicker.show(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (range == null || !mounted) return;
    setState(() {
      _dateFilter = 'custom';
      _customStart = range.start;
      _customEnd = range.end;
    });
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _dateFilter = 'all';
      _statusFilter = null;
      _customStart = null;
      _customEnd = null;
    });
  }

  Future<void> _updateStatus(RestaurantOrder order, OrderStatus status) async {
    final actor = getIt<UserCubit>().currentUser;
    if (!PermissionGuard.can(actor, AppPermission.updateOrders)) {
      MotionSnackBarError(context, 'ليس لديك صلاحية تحديث حالة الطلبات.');
      return;
    }
    final cubit = context.read<OrdersCubit>();
    await cubit.updateStatus(order, status, actor: actor);
    if (!mounted || cubit.state.error != null) return;
    MotionSnackBarSuccess(
      context,
      'تم تحديث الطلب #${order.orderNumber} إلى ${status.displayName}.',
    );
  }

  Future<void> _markPaid(RestaurantOrder order) async {
    final actor = getIt<UserCubit>().currentUser;
    if (!PermissionGuard.can(actor, AppPermission.processPayments)) {
      MotionSnackBarError(context, 'ليس لديك صلاحية تسجيل المدفوعات.');
      return;
    }
    final capture = await _capturePayment();
    if (capture == null || !mounted) return;
    final cubit = context.read<OrdersCubit>();
    await cubit.markPaid(
      order,
      actor: actor,
      method: capture.method,
      referenceNumber: capture.referenceNumber,
    );
    if (!mounted || cubit.state.error != null) return;
    MotionSnackBarSuccess(
      context,
      'تم تسجيل دفع الطلب #${order.orderNumber} بنجاح.',
    );
  }

  Future<_PaymentCapture?> _capturePayment() async {
    final referenceController = TextEditingController();
    var method = 'cash';
    final result = await showDialog<_PaymentCapture>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              LucideIcons.walletCards,
              color: AppColors.successGreen,
            ),
          ),
          title: Text(
            'تسجيل الرصيد المتبقي',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 390,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: method,
                  dropdownColor: AppColors.surfaceColor,
                  decoration: const InputDecoration(
                    labelText: 'طريقة الدفع',
                    prefixIcon: Icon(LucideIcons.creditCard),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                    DropdownMenuItem(value: 'card', child: Text('بطاقة')),
                    DropdownMenuItem(
                        value: 'mobile', child: Text('محفظة إلكترونية')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => method = value);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: referenceController,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم المرجع (اختياري)',
                    prefixIcon: Icon(LucideIcons.receiptText),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                dialogContext,
                _PaymentCapture(
                  method: method,
                  referenceNumber: referenceController.text.trim().isEmpty
                      ? null
                      : referenceController.text.trim(),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.successGreen,
              ),
              icon: const Icon(LucideIcons.checkCheck, size: 17),
              label: const Text('تأكيد الدفع'),
            ),
          ],
        ),
      ),
    );
    referenceController.dispose();
    return result;
  }

  Future<void> _cancelOrder(RestaurantOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.grillRed.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(LucideIcons.circleX, color: AppColors.grillRed),
        ),
        title: Text(
          'إلغاء الطلب #${order.orderNumber}',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'لن يظهر الطلب ضمن الطلبات النشطة بعد الإلغاء. هل تريد المتابعة؟',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('العودة'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.grillRed),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _updateStatus(order, OrderStatus.cancelled);
    }
  }

  Future<void> _showOrderDetails(RestaurantOrder order) async {
    final actor = getIt<UserCubit>().currentUser;
    final canUpdate = PermissionGuard.can(actor, AppPermission.updateOrders);
    final canPay = PermissionGuard.can(actor, AppPermission.processPayments);
    final legalStatuses = OrdersRepository.legalNextStatuses(order);
    final forwardStatuses = legalStatuses
        .where((status) => status != OrderStatus.cancelled)
        .toList(growable: false);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _OrderDetailsDialog(
        order: order,
        allowedStatuses: forwardStatuses,
        onStatusChanged: canUpdate && forwardStatuses.isNotEmpty
            ? (status) async {
                Navigator.pop(dialogContext);
                await _updateStatus(order, status);
              }
            : null,
        onMarkPaid: canPay &&
                order.status != OrderStatus.cancelled &&
                order.paymentStatus != PaymentStatus.paid
            ? () async {
                Navigator.pop(dialogContext);
                await _markPaid(order);
              }
            : null,
        onCancel: canUpdate && legalStatuses.contains(OrderStatus.cancelled)
            ? () async {
                Navigator.pop(dialogContext);
                await _cancelOrder(order);
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: SafeArea(
          child: BlocListener<OrdersCubit, OrdersState>(
            listenWhen: (previous, current) =>
                previous.error != current.error && current.error != null,
            listener: (context, state) {
              if (state.error != null) {
                MotionSnackBarError(context, state.error!);
              }
            },
            child: BlocBuilder<OrdersCubit, OrdersState>(
              builder: (context, state) {
                if (state.loading &&
                    state.activeOrders.isEmpty &&
                    state.historyOrders.isEmpty) {
                  return const _OrdersLoadingState();
                }
                if (state.error != null &&
                    state.activeOrders.isEmpty &&
                    state.historyOrders.isEmpty) {
                  return _OrdersErrorState(
                    message: state.error!,
                    onRetry: () => context.read<OrdersCubit>().loadOrders(),
                  );
                }

                final datedActive = _filterByDate(state.activeOrders);
                final datedHistory = _filterByDate(state.historyOrders);
                final searchedActive = _filterByQuery(datedActive);
                final searchedHistory = _filterByQuery(datedHistory);
                final visibleActive = _applyStatusFilter(searchedActive);
                final visibleHistory = _applyStatusFilter(searchedHistory);
                final unfilteredTabOrders =
                    _tabIndex == 0 ? searchedActive : searchedHistory;
                final statuses = _tabIndex == 0
                    ? const [
                        OrderStatus.pending,
                        OrderStatus.preparing,
                        OrderStatus.ready,
                        OrderStatus.served,
                      ]
                    : const [OrderStatus.completed, OrderStatus.cancelled];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        0,
                      ),
                      child: ScreenHeader(
                        title: 'إدارة الطلبات',
                        subtitle:
                            'متابعة التحضير، الدفع وتسليم الطلبات من مساحة عمل واحدة',
                        icon: LucideIcons.receipt,
                        trailingWidget: _RefreshButton(
                          loading: state.loading,
                          onPressed: () =>
                              context.read<OrdersCubit>().loadOrders(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: _OrdersSummary(
                        activeOrders: datedActive,
                        historyOrders: datedHistory,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: _OrdersToolbar(
                        controller: _searchController,
                        dateFilter: _dateFilter,
                        customStart: _customStart,
                        customEnd: _customEnd,
                        onSearch: (value) => setState(() => _query = value),
                        onDateChanged: (value) =>
                            setState(() => _dateFilter = value),
                        onCustomDate: _pickDateRange,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: _OrdersTabs(
                        activeCount: searchedActive.length,
                        historyCount: searchedHistory.length,
                        onTap: (index) => setState(() {
                          _tabIndex = index;
                          _statusFilter = null;
                        }),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: _StatusFilters(
                        statuses: statuses,
                        orders: unfilteredTabOrders,
                        selected: _statusFilter,
                        onSelected: (status) =>
                            setState(() => _statusFilter = status),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _OrdersList(
                            orders: visibleActive,
                            active: true,
                            hasFilters: _hasFilters,
                            onResetFilters: _resetFilters,
                            onRefresh: () =>
                                context.read<OrdersCubit>().loadOrders(),
                            onTap: _showOrderDetails,
                          ),
                          _OrdersList(
                            orders: visibleHistory,
                            active: false,
                            hasFilters: _hasFilters,
                            onResetFilters: _resetFilters,
                            onRefresh: () =>
                                context.read<OrdersCubit>().loadOrders(),
                            onTap: _showOrderDetails,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasFilters =>
      _query.trim().isNotEmpty || _statusFilter != null || _dateFilter != 'all';
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.refreshCw, size: 17),
      label: Text(loading ? 'جاري التحديث' : 'تحديث'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _OrdersSummary extends StatelessWidget {
  const _OrdersSummary(
      {required this.activeOrders, required this.historyOrders});

  final List<RestaurantOrder> activeOrders;
  final List<RestaurantOrder> historyOrders;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _SummaryData(
        'الطلبات النشطة',
        '${activeOrders.length}',
        LucideIcons.receipt,
        AppColors.blueMuted,
      ),
      _SummaryData(
        'بانتظار البدء',
        '${activeOrders.where((order) => order.status == OrderStatus.pending).length}',
        LucideIcons.clock,
        AppColors.ember,
      ),
      _SummaryData(
        'جاهزة للتسليم',
        '${activeOrders.where((order) => order.status == OrderStatus.ready).length}',
        LucideIcons.circleCheck,
        AppColors.successGreen,
      ),
      _SummaryData(
        'تحتاج متابعة',
        '${activeOrders.where((order) => order.elapsed.inMinutes >= 20).length}',
        LucideIcons.triangleAlert,
        AppColors.grillRed,
      ),
      _SummaryData(
        'مبيعات الفترة',
        '${_money(
          historyOrders
              .where(
                (order) =>
                    order.status == OrderStatus.completed &&
                    order.paymentStatus == PaymentStatus.paid,
              )
              .fold<double>(0, (sum, order) => sum + order.totalAmount),
        )} ج.م',
        LucideIcons.walletCards,
        AppColors.warmOrange,
      ),
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => SizedBox(
          width: 210,
          child: _SummaryCard(data: stats[index]),
        ),
      ),
    );
  }
}

class _SummaryData {
  const _SummaryData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersToolbar extends StatelessWidget {
  const _OrdersToolbar({
    required this.controller,
    required this.dateFilter,
    required this.customStart,
    required this.customEnd,
    required this.onSearch,
    required this.onDateChanged,
    required this.onCustomDate,
  });

  final TextEditingController controller;
  final String dateFilter;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onDateChanged;
  final VoidCallback onCustomDate;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: controller,
      onChanged: onSearch,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'ابحث برقم الطلب، الطاولة أو الصنف...',
        prefixIcon: const Icon(LucideIcons.search, size: 18),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'مسح البحث',
                onPressed: () {
                  controller.clear();
                  onSearch('');
                },
                icon: const Icon(LucideIcons.x, size: 17),
              ),
        filled: true,
        fillColor: AppColors.surfaceColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.warmOrange),
        ),
      ),
    );
    final dates = _DateFilters(
      selected: dateFilter,
      customLabel: _customLabel,
      onChanged: onDateChanged,
      onCustomDate: onCustomDate,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 850) {
          return Column(
            children: [
              search,
              const SizedBox(height: 10),
              dates,
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 330, child: search),
            const SizedBox(width: 12),
            Expanded(child: dates),
          ],
        );
      },
    );
  }

  String get _customLabel {
    if (customStart == null || customEnd == null) return 'فترة مخصصة';
    final formatter = DateFormat('dd/MM');
    return '${formatter.format(customStart!)} - ${formatter.format(customEnd!)}';
  }
}

class _DateFilters extends StatelessWidget {
  const _DateFilters({
    required this.selected,
    required this.customLabel,
    required this.onChanged,
    required this.onCustomDate,
  });

  final String selected;
  final String customLabel;
  final ValueChanged<String> onChanged;
  final VoidCallback onCustomDate;

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('today', 'اليوم', LucideIcons.calendar),
      ('week', '7 أيام', LucideIcons.calendarDays),
      ('month', 'الشهر', LucideIcons.calendarRange),
      ('year', 'السنة', LucideIcons.calendarCheck),
      ('all', 'الكل', LucideIcons.infinity),
    ];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...filters.map(
            (filter) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 7),
              child: _FilterChip(
                label: filter.$2,
                icon: filter.$3,
                selected: selected == filter.$1,
                onTap: () => onChanged(filter.$1),
              ),
            ),
          ),
          _FilterChip(
            label: customLabel,
            icon: LucideIcons.calendarSearch,
            selected: selected == 'custom',
            onTap: onCustomDate,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.warmOrange.withValues(alpha: .12)
                : AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.warmOrange.withValues(alpha: .6)
                  : AppColors.borderColor,
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
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? AppColors.warmOrange : AppColors.textPrimary,
                  fontSize: 11,
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

class _OrdersTabs extends StatelessWidget {
  const _OrdersTabs({
    required this.activeCount,
    required this.historyCount,
    required this.onTap,
  });

  final int activeCount;
  final int historyCount;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: TabBar(
        onTap: onTap,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: AppColors.orangeGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: [
          _TabLabel(
            icon: LucideIcons.clock,
            label: 'الطلبات النشطة',
            count: activeCount,
          ),
          _TabLabel(
            icon: LucideIcons.history,
            label: 'سجل الطلبات',
            count: historyCount,
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel(
      {required this.icon, required this.label, required this.count});

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count',
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({
    required this.statuses,
    required this.orders,
    required this.selected,
    required this.onSelected,
  });

  final List<OrderStatus> statuses;
  final List<RestaurantOrder> orders;
  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _StatusChip(
            label: 'كل الحالات',
            count: orders.length,
            color: AppColors.warmOrange,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          ...statuses.map(
            (status) => Padding(
              padding: const EdgeInsetsDirectional.only(start: 7),
              child: _StatusChip(
                label: status.displayName,
                count: orders.where((order) => order.status == status).length,
                color: _statusColor(status),
                selected: selected == status,
                onTap: () => onSelected(status),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .14) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? color.withValues(alpha: .5) : AppColors.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: selected ? color : AppColors.mutedColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.active,
    required this.hasFilters,
    required this.onResetFilters,
    required this.onRefresh,
    required this.onTap,
  });

  final List<RestaurantOrder> orders;
  final bool active;
  final bool hasFilters;
  final VoidCallback onResetFilters;
  final Future<void> Function() onRefresh;
  final ValueChanged<RestaurantOrder> onTap;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _OrdersEmptyState(
        active: active,
        hasFilters: hasFilters,
        onResetFilters: onResetFilters,
        onRefresh: onRefresh,
      );
    }

    final delayedCount = active
        ? orders.where((order) => order.elapsed.inMinutes >= 20).length
        : 0;
    return RefreshIndicator(
      color: AppColors.warmOrange,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1180 ? 2 : 1;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: _ListHeading(
                    active: active,
                    count: orders.length,
                    delayedCount: delayedCount,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final order = orders[index];
                      return OrderCard(order: order, onTap: () => onTap(order));
                    },
                    childCount: orders.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: 2,
                    mainAxisExtent: constraints.maxWidth < 560
                        ? 124
                        : columns == 1
                            ? 86
                            : 120,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ListHeading extends StatelessWidget {
  const _ListHeading({
    required this.active,
    required this.count,
    required this.delayedCount,
  });

  final bool active;
  final int count;
  final int delayedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                active ? 'قائمة التنفيذ الحالية' : 'الطلبات المكتملة والملغاة',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                active
                    ? 'اضغط على الطلب لعرض التفاصيل وتحديث حالته'
                    : 'اضغط على أي طلب لمراجعة تفاصيله',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        if (delayedCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.grillRed.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.grillRed.withValues(alpha: .25)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.triangleAlert,
                    size: 14, color: AppColors.grillRed),
                const SizedBox(width: 5),
                Text(
                  '$delayedCount متأخر',
                  style: const TextStyle(
                    color: AppColors.grillRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            '$count طلب',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState({
    required this.active,
    required this.hasFilters,
    required this.onResetFilters,
    required this.onRefresh,
  });

  final bool active;
  final bool hasFilters;
  final VoidCallback onResetFilters;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.warmOrange,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.warmOrange.withValues(alpha: .09),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters
                    ? LucideIcons.searchX
                    : active
                        ? LucideIcons.receipt
                        : LucideIcons.history,
                color: AppColors.warmOrange,
                size: 31,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasFilters
                ? 'لا توجد طلبات تطابق الفلاتر'
                : active
                    ? 'لا توجد طلبات نشطة الآن'
                    : 'سجل الطلبات فارغ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasFilters
                ? 'جرّب تغيير حالة الطلب أو الفترة الزمنية أو عبارة البحث.'
                : active
                    ? 'ستظهر الطلبات الجديدة هنا فور تسجيلها من نقطة البيع.'
                    : 'ستظهر هنا الطلبات المكتملة والملغاة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Center(
            child: hasFilters
                ? OutlinedButton.icon(
                    onPressed: onResetFilters,
                    icon: const Icon(LucideIcons.rotateCcw, size: 16),
                    label: const Text('مسح الفلاتر'),
                  )
                : OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('تحديث الطلبات'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrdersLoadingState extends StatelessWidget {
  const _OrdersLoadingState();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.warmOrange),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل الطلبات...',
              style: TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersErrorState extends StatelessWidget {
  const _OrdersErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundColor,
      child: Center(
        child: Container(
          width: 440,
          margin: const EdgeInsets.all(AppSpacing.lg),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.grillRed.withValues(alpha: .3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.circleAlert,
                  color: AppColors.grillRed, size: 34),
              const SizedBox(height: 12),
              Text(
                'تعذر تحميل الطلبات',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailsDialog extends StatelessWidget {
  const _OrderDetailsDialog({
    required this.order,
    required this.allowedStatuses,
    required this.onStatusChanged,
    required this.onMarkPaid,
    required this.onCancel,
  });

  final RestaurantOrder order;
  final List<OrderStatus> allowedStatuses;
  final ValueChanged<OrderStatus>? onStatusChanged;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    final elapsedMinutes = order.elapsed.inMinutes;
    return Dialog(
      backgroundColor: AppColors.surfaceColor,
      insetPadding: const EdgeInsets.all(18),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
              decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: AppColors.borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(_orderTypeIcon(order.orderType),
                        color: color, size: 22),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تفاصيل الطلب #${order.orderNumber}',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.orderType.displayName}${order.tableId == null ? '' : '  •  ${_tableLabel(order.tableId!)}'}  •  ${DateFormat('dd/MM/yyyy - HH:mm').format(order.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  _DialogPill(label: order.status.displayName, color: color),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(LucideIcons.x,
                        color: AppColors.textSecondary, size: 19),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OrderMetaGrid(order: order),
                    if (order.isActive && elapsedMinutes >= 20) ...[
                      const SizedBox(height: 14),
                      _DelayedOrderBanner(minutes: elapsedMinutes),
                    ],
                    const SizedBox(height: 22),
                    _SectionTitle(
                      title: 'عناصر الطلب',
                      trailing: '${order.items.length} صنف',
                    ),
                    const SizedBox(height: 10),
                    _OrderItems(items: order.items),
                    if (order.notes?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 18),
                      _OrderNotes(notes: order.notes!.trim()),
                    ],
                    const SizedBox(height: 18),
                    _OrderTotals(order: order),
                    if (onStatusChanged != null) ...[
                      const SizedBox(height: 22),
                      const _SectionTitle(title: 'تحديث مرحلة التنفيذ'),
                      const SizedBox(height: 10),
                      _LifecycleActions(
                        statuses: allowedStatuses,
                        onChanged: onStatusChanged!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 16),
              decoration: BoxDecoration(
                color: AppColors.charcoalLight,
                border: Border(top: BorderSide(color: AppColors.borderColor)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final actions = <Widget>[
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إغلاق'),
                    ),
                    if (onCancel != null)
                      OutlinedButton.icon(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.grillRed,
                          side: BorderSide(
                              color: AppColors.grillRed.withValues(alpha: .45)),
                        ),
                        icon: const Icon(LucideIcons.circleX, size: 16),
                        label: const Text('إلغاء الطلب'),
                      ),
                    if (onMarkPaid != null)
                      FilledButton.icon(
                        onPressed: onMarkPaid,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(LucideIcons.checkCheck, size: 17),
                        label: const Text('تسجيل الدفع'),
                      ),
                  ];
                  return Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 9,
                    runSpacing: 9,
                    children: actions,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderMetaGrid extends StatelessWidget {
  const _OrderMetaGrid({required this.order});

  final RestaurantOrder order;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'نوع الطلب',
        order.orderType.displayName,
        _orderTypeIcon(order.orderType)
      ),
      (
        'الموقع',
        order.tableId == null ? 'بدون طاولة' : _tableLabel(order.tableId!),
        LucideIcons.mapPin
      ),
      (
        'حالة الدفع',
        _paymentLabel(order.paymentStatus),
        LucideIcons.walletCards
      ),
      (
        'وقت الطلب',
        DateFormat('HH:mm').format(order.createdAt),
        LucideIcons.clock
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 500
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 30) / 4;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.charcoalLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.$3, size: 16, color: AppColors.warmOrange),
                        const SizedBox(height: 8),
                        Text(
                          item.$1,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 10),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DelayedOrderBanner extends StatelessWidget {
  const _DelayedOrderBanner({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.grillRed.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grillRed.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.triangleAlert,
              color: AppColors.grillRed, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'الطلب مفتوح منذ $minutes دقيقة ويحتاج إلى متابعة سريعة.',
              style: const TextStyle(
                color: AppColors.grillRed,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(trailing!,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ],
    );
  }
}

class _OrderItems extends StatelessWidget {
  const _OrderItems({required this.items});

  final List<OrderItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.charcoalLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Text(
          'لا توجد عناصر مسجلة لهذا الطلب.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: index == items.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: AppColors.borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.warmOrange.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _quantity(item.quantity),
                    style: const TextStyle(
                      color: AppColors.warmOrange,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.notes?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.notes!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_money(item.subtotal)} ج.م',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _OrderNotes extends StatelessWidget {
  const _OrderNotes({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.blueMuted.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blueMuted.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.stickyNote,
              color: AppColors.blueMuted, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملاحظات الطلب',
                  style: TextStyle(
                    color: AppColors.blueMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(notes,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTotals extends StatelessWidget {
  const _OrderTotals({required this.order});

  final RestaurantOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          _TotalLine(label: 'المجموع الفرعي', value: order.subtotal),
          if (order.tax != 0) _TotalLine(label: 'الضريبة', value: order.tax),
          if (order.discount != 0)
            _TotalLine(
                label: 'الخصم',
                value: -order.discount,
                valueColor: AppColors.successGreen),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.borderColor),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'الإجمالي',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${_money(order.totalAmount)} ج.م',
                style: const TextStyle(
                  color: AppColors.warmOrange,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.value, this.valueColor});

  final String label;
  final double value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 11))),
          Text(
            '${_money(value)} ج.م',
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifecycleActions extends StatelessWidget {
  const _LifecycleActions({required this.statuses, required this.onChanged});

  final List<OrderStatus> statuses;
  final ValueChanged<OrderStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((status) {
        final color = _statusColor(status);
        return InkWell(
          onTap: () => onChanged(status),
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: color.withValues(alpha: .35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.arrowLeft, color: color, size: 14),
                const SizedBox(width: 5),
                Text(
                  status.displayName,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PaymentCapture {
  const _PaymentCapture({required this.method, this.referenceNumber});

  final String method;
  final String? referenceNumber;
}

class _DialogPill extends StatelessWidget {
  const _DialogPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

Color _statusColor(OrderStatus status) => switch (status) {
      OrderStatus.pending => AppColors.blueMuted,
      OrderStatus.preparing => AppColors.ember,
      OrderStatus.ready => AppColors.successGreen,
      OrderStatus.served => const Color(0xFF8B5CF6),
      OrderStatus.completed => const Color(0xFF64748B),
      OrderStatus.cancelled => AppColors.grillRed,
    };

IconData _orderTypeIcon(OrderType type) => switch (type) {
      OrderType.dineIn => LucideIcons.utensils,
      OrderType.takeaway => LucideIcons.shoppingBag,
      OrderType.delivery => LucideIcons.bike,
    };

String _paymentLabel(PaymentStatus status) => switch (status) {
      PaymentStatus.unpaid => 'غير مدفوع',
      PaymentStatus.partial => 'مدفوع جزئياً',
      PaymentStatus.paid => 'مدفوع بالكامل',
    };

String _tableLabel(String tableId) {
  final value = tableId.replaceAll('table_', '').replaceAll('Table', '').trim();
  return 'طاولة $value';
}

String _money(double value) => value.toStringAsFixed(2);

String _quantity(double value) => value == value.roundToDouble()
    ? '${value.toInt()}×'
    : '${value.toStringAsFixed(1)}×';
