import 'package:grill_pos/features/auth/presentation/cubit/user_cubit.dart';
import 'package:grill_pos/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';



class CloseDayCard extends StatelessWidget {
  final bool isMobile;

  const CloseDayCard({super.key, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => UserCubit.get(context).closeSession(),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.grillRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.doorClosed,
                  color: AppColors.grillRed,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إغلاق اليومية',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 16 : 18,
                            color: AppColors.cream,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إنهاء الوردية الحالية وإصدار تقرير الإغلاق',
                      style:Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.mutedColor,
                            ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.mutedColor),
            ],
          ),
        ),
      ),
    );
  }

}
