import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/cubit/user_cubit.dart';

class CloseDayCard extends StatelessWidget {
  const CloseDayCard({super.key, required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ember.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.ember.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.clockArrowDown,
                  color: AppColors.ember,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إغلاق الوردية',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'إنهاء العمل وإصدار تقرير الإغلاق',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.ember.withValues(alpha: .055),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.info, color: AppColors.ember, size: 15),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'تأكد من اكتمال كل الطلبات قبل إغلاق الوردية.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _confirmCloseDay(context),
            icon: const Icon(LucideIcons.doorClosed, size: 16),
            label: const Text('إغلاق الوردية الحالية'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ember,
              backgroundColor: AppColors.ember.withValues(alpha: .045),
              side: BorderSide(color: AppColors.ember.withValues(alpha: .3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCloseDay(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.ember.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            LucideIcons.clockArrowDown,
            color: AppColors.ember,
            size: 25,
          ),
        ),
        title: const Text('إغلاق الوردية الحالية'),
        content: const Text(
          'سيتم إنهاء الوردية وإصدار تقرير الإغلاق. هل تريد المتابعة؟',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.ember),
            icon: const Icon(LucideIcons.check, size: 16),
            label: const Text('تأكيد الإغلاق'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      UserCubit.get(context).closeSession();
    }
  }
}
