import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';


class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;
  final bool isPositiveTrend;
  final VoidCallback? onTap;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
    required this.isPositiveTrend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;
              
              // Extremely compact layout if height is very small
              if (h < 95) {
                return _buildCompactLayout(h, w);
              }

              return _buildDefaultLayout(h, w);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultLayout(double h, double w) {
    final isMid = h < 140;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.creamMuted,
                  fontSize: isMid ? 11 : 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: EdgeInsets.all(isMid ? 6 : 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: isMid ? 16 : 20),
            ),
          ],
        ),
        if (!isMid) const Spacer(),
        if (isMid) const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.cream,
              fontSize: isMid ? 18 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositiveTrend ? Icons.trending_up : Icons.trending_down,
                color: isPositiveTrend ? AppColors.successColor : AppColors.errorColor,
                size: 10,
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: TextStyle(
                  color: isPositiveTrend ? AppColors.successColor : AppColors.errorColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(double h, double w) {
     return Row(
       children: [
         Container(
           padding: const EdgeInsets.all(6),
           decoration: BoxDecoration(
             color: color.withOpacity(0.12),
             borderRadius: BorderRadius.circular(8),
           ),
           child: Icon(icon, color: color, size: 16),
         ),
         const SizedBox(width: 8),
         Expanded(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               FittedBox(
                 fit: BoxFit.scaleDown,
                 alignment: AlignmentDirectional.centerStart,
                 child: Text(
                   title,
                   style: TextStyle(
                     color: AppColors.creamMuted,
                     fontSize: 10,
                     fontWeight: FontWeight.w600,
                   ),
                 ),
               ),
               FittedBox(
                 fit: BoxFit.scaleDown,
                 alignment: AlignmentDirectional.centerStart,
                 child: Text(
                   value,
                   style: TextStyle(
                     color: AppColors.cream,
                     fontSize: 16,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
               ),
             ],
           ),
         ),
       ],
     );
  }
}
