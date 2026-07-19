import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../features/orders/data/order_models.dart';
import '../constants/app_colors.dart';

/// A responsive order summary used by the dashboard and the orders workspace.
class OrderCard extends StatefulWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.compact = false,
  });

  final RestaurantOrder order;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final statusColor = _statusColor(order.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.006 : 1,
        duration: const Duration(milliseconds: 160),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 9),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color:
                _hovered ? AppColors.charcoalLight : AppColors.charcoalMedium,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? statusColor.withValues(alpha: .48)
                  : AppColors.borderColor,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: statusColor.withValues(alpha: isDark ? .12 : .08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              child: Stack(
                children: [
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 4,
                      color: statusColor,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      widget.compact ? 17 : 20,
                      widget.compact ? 12 : 14,
                      widget.compact ? 13 : 16,
                      widget.compact ? 12 : 14,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 520;
                        return narrow
                            ? _NarrowOrderContent(
                                order: order,
                                statusColor: statusColor,
                              )
                            : _WideOrderContent(
                                order: order,
                                statusColor: statusColor,
                              );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WideOrderContent extends StatelessWidget {
  const _WideOrderContent({required this.order, required this.statusColor});

  final RestaurantOrder order;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OrderIcon(order: order, color: statusColor),
        const SizedBox(width: 13),
        Expanded(
          flex: 4,
          child: _OrderIdentity(order: order),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusPill(
                label: order.status.displayName,
                color: statusColor,
              ),
              _StatusPill(
                label: _paymentLabel(order.paymentStatus),
                color: _paymentColor(order.paymentStatus),
                outlined: true,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _OrderAmount(order: order),
        const SizedBox(width: 10),
        Icon(
          LucideIcons.chevronLeft,
          size: 18,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}

class _NarrowOrderContent extends StatelessWidget {
  const _NarrowOrderContent({required this.order, required this.statusColor});

  final RestaurantOrder order;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _OrderIcon(order: order, color: statusColor),
            const SizedBox(width: 11),
            Expanded(child: _OrderIdentity(order: order)),
            _OrderAmount(order: order),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _StatusPill(label: order.status.displayName, color: statusColor),
            _StatusPill(
              label: _paymentLabel(order.paymentStatus),
              color: _paymentColor(order.paymentStatus),
              outlined: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderIcon extends StatelessWidget {
  const _OrderIcon({required this.order, required this.color});

  final RestaurantOrder order;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 43,
      height: 43,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Icon(_orderTypeIcon(order.orderType), color: color, size: 21),
    );
  }
}

class _OrderIdentity extends StatelessWidget {
  const _OrderIdentity({required this.order});

  final RestaurantOrder order;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      order.orderType.displayName,
      if (order.tableId != null) _tableLabel(order.tableId!),
      '${order.items.length} صنف',
      _timeLabel(order),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '#${order.orderNumber}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: .1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          metadata.join('  •  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: order.isActive && order.elapsed.inMinutes >= 20
                ? AppColors.grillRed
                : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OrderAmount extends StatelessWidget {
  const _OrderAmount({required this.order});

  final RestaurantOrder order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          order.totalAmount.toStringAsFixed(2),
          style: const TextStyle(
            color: AppColors.warmOrange,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          'ج.م',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: outlined ? .06 : .13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: outlined ? .35 : .2)),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
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

Color _paymentColor(PaymentStatus status) => switch (status) {
      PaymentStatus.unpaid => AppColors.grillRed,
      PaymentStatus.partial => AppColors.ember,
      PaymentStatus.paid => AppColors.successGreen,
    };

String _paymentLabel(PaymentStatus status) => switch (status) {
      PaymentStatus.unpaid => 'غير مدفوع',
      PaymentStatus.partial => 'دفع جزئي',
      PaymentStatus.paid => 'مدفوع',
    };

IconData _orderTypeIcon(OrderType type) => switch (type) {
      OrderType.dineIn => LucideIcons.utensils,
      OrderType.takeaway => LucideIcons.shoppingBag,
      OrderType.delivery => LucideIcons.bike,
    };

String _tableLabel(String tableId) {
  final value = tableId.replaceAll('table_', '').replaceAll('Table', '').trim();
  return 'طاولة $value';
}

String _timeLabel(RestaurantOrder order) {
  if (order.isActive) {
    final minutes = order.elapsed.inMinutes;
    return minutes < 1 ? 'الآن' : 'منذ $minutes د';
  }
  return DateFormat('HH:mm').format(order.createdAt);
}
