import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class CustomDateRangePicker {
  static Future<DateTimeRange?> show({
    required BuildContext context,
    DateTime? firstDate,
    DateTime? lastDate,
    DateTimeRange? initialDateRange,
  }) async {
    final first = firstDate ?? DateTime(2024);
    final last = lastDate ?? DateTime.now();

    return await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: initialDateRange,
      locale: const Locale('ar', 'EG'),
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 450,
              maxHeight: 600,
            ),
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 1.5),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: AppColors.warmOrange,
                      onPrimary: Colors.white,
                      surface: AppColors.charcoalMedium,
                      onSurface: AppColors.cream,
                      secondary: AppColors.warmOrange,
                    ),
                    dialogTheme: DialogThemeData(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 1.5),
                      ),
                      backgroundColor: AppColors.charcoalDark,
                    ),
                    scaffoldBackgroundColor: AppColors.charcoalDark,
                    cardTheme: CardThemeData(
                      color: AppColors.charcoalMedium,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                      ),
                    ),
                    dividerColor: AppColors.borderColor,
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.warmOrange,
                      ),
                    ),
                  ),
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
