import 'package:flutter/material.dart';

import '../../../features/orders/data/order_models.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class OrderCard extends StatelessWidget {
  final RestaurantOrder order;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    order.orderType.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cream,
                          ),
                        ),
                        Text(
                          '${order.totalAmount.toStringAsFixed(2)} ج.م',
                          style: TextStyle(
                            fontSize: 16,
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                order.status.displayName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (order.tableId != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.charcoalLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.borderColor),
                                ),
                                child: Text(
                                  'طاولة ${order.tableId?.replaceAll('table_', '').replaceAll('Table', '').trim()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.cream,
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
                              fontSize: 13,
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
    );
  }
}
