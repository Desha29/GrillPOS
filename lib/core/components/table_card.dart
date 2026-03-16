import 'package:flutter/material.dart';

import '../../../features/tables/data/table_models.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class TableCard extends StatelessWidget {
  final RestaurantTable table;
  final VoidCallback onTap;

  const TableCard({
    super.key,
    required this.table,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;
    switch (table.status) {
      case TableStatus.available:
        statusColor = AppColors.successGreen;
        statusBgColor = AppColors.successGreen.withOpacity(0.1);
        statusIcon = Icons.restaurant;
        break;
      case TableStatus.occupied:
        statusColor = AppColors.grillRed;
        statusBgColor = AppColors.grillRed.withOpacity(0.1);
        statusIcon = Icons.person;
        break;
      case TableStatus.reserved:
        statusColor = AppColors.ember;
        statusBgColor = AppColors.ember.withOpacity(0.1);
        statusIcon = Icons.event_available;
        break;
      case TableStatus.cleaning:
        statusColor = AppColors.warningColor;
        statusBgColor = AppColors.warningColor.withOpacity(0.1);
        statusIcon = Icons.cleaning_services;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: table.status != TableStatus.available 
              ? statusColor.withOpacity(0.5) 
              : AppColors.borderColor,
          width: table.status != TableStatus.available ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 28),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  table.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 14, color: AppColors.mutedColor),
                    const SizedBox(width: 4),
                    Text(
                      '${table.capacity} مقاعد',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.creamMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    table.status.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
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
