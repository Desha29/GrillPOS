import 'package:flutter/material.dart';

import '../../../features/orders/data/order_models.dart';
import '../constants/app_colors.dart';

class OrderCard extends StatefulWidget {
  final RestaurantOrder order;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final order = widget.order;

    Color statusColor;
    switch (order.status) {
      case OrderStatus.pending:
        statusColor = AppColors.warningColor;
        break;
      case OrderStatus.preparing:
        statusColor = AppColors.ember;
        break;
      case OrderStatus.ready:
        statusColor = AppColors.successColor;
        break;
      default:
        statusColor = AppColors.mutedColor;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark
              ? (_hovered
                  ? AppColors.charcoalLight.withOpacity(0.7)
                  : AppColors.charcoalMedium.withOpacity(0.5))
              : (_hovered
                  ? Colors.white
                  : const Color(0xFFF7F8FA)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered
                ? statusColor.withOpacity(0.5)
                : AppColors.borderColor.withOpacity(isDark ? 0.3 : 0.5),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: statusColor.withOpacity(isDark ? 0.12 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Order type icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        order.orderType.icon,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Order details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${order.orderType.displayName} #${order.orderNumber}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.cream,
                              ),
                            ),
                            Text(
                              '${order.totalAmount.toStringAsFixed(2)} ج.م',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.warmOrange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    order.status.displayName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (order.tableId != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.charcoalLight
                                          : const Color(0xFFEEF0F5),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.borderColor
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                    child: Text(
                                      'طاولة ${order.tableId?.replaceAll('table_', '').replaceAll('Table', '').trim()}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.cream,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                            Flexible(
                              child: Text(
                                '${order.elapsed.inMinutes} دقيقة',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: order.elapsed.inMinutes > 20
                                      ? AppColors.grillRed
                                      : AppColors.mutedColor,
                                  fontWeight: order.elapsed.inMinutes > 20
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
