import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grill_pos/core/components/screen_header.dart';
import 'package:grill_pos/core/constants/app_colors.dart';
import 'package:grill_pos/features/auth/presentation/cubit/user_cubit.dart';

import 'package:grill_pos/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:grill_pos/core/functions/messege.dart';
import '../../../core/di/dependency_injection.dart';

import '../../auth/data/models/user_model.dart';
import '../../auth/presentation/cubit/user_states.dart';

import '../../sessions/data/models/daily_report_model.dart';
import '../../sessions/presentation/screens/daily_report_preview_screen.dart';
import 'widgets/close_day_card.dart';
import 'widgets/logout_warning_banner.dart';
import 'widgets/store_info_card.dart';
import 'widgets/data_management_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<UserCubit>.value(value: getIt<UserCubit>()..getAllUsers()),
        BlocProvider.value(value: getIt<SettingsCubit>()),
      ],
      child: const _SettingsScreenContent(),
    );
  }
}

class _SettingsScreenContent extends StatelessWidget {
  const _SettingsScreenContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      body: BlocListener<UserCubit, UserStates>(
        listener: (context, state) {
          if (state is CloseSessionLoading) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (c) => Center(child: CircularProgressIndicator(color: AppColors.warmOrange)),
            );
          } else if (state is UserFailure) {
            if (state.error.contains("إغلاق")) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            MotionSnackBarError(context, state.error);
          } else if (state is UserSuccessWithReport) {
            Navigator.of(context, rootNavigator: true).pop();

            final userCubit = getIt<UserCubit>();
            if (userCubit.currentUser.userType == UserType.manager) {
              _showReportDialog(context, state.report);
            } else {
              MotionSnackBarSuccess(context, "تم إغلاق اليوم بنجاح. جاري تسجيل الخروج...");
              Future.delayed(const Duration(milliseconds: 1500), () {
                userCubit.logout();
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              });
            }
          } else if (state is UserSuccess) {
            MotionSnackBarSuccess(context, state.message);
          }
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final padding = isMobile ? 16.0 : 24.0;

              return Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ScreenHeader(
                      title: 'الإعدادات',
                      subtitle: 'إعدادات المطعم، البيانات، وإغلاق اليوم',
                      icon: Icons.settings,
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    LogoutWarningBanner(isMobile: isMobile),
                    SizedBox(height: isMobile ? 12 : 16),
                    Expanded(
                      child: ListView(
                        children: [
                          if (getIt<UserCubit>().currentUser.userType == UserType.manager) ...[
                            DataManagementCard(isMobile: isMobile),
                            SizedBox(height: isMobile ? 12 : 16),
                          ],
                          StoreInfoCard(isMobile: isMobile),
                          SizedBox(height: isMobile ? 12 : 16),
                          CloseDayCard(isMobile: isMobile),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, DailyReport report) {
    final userCubit = getIt<UserCubit>();
    final isManager = userCubit.currentUser.userType == UserType.manager;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.charcoalMedium,
        title: Text('تم إغلاق اليوم بنجاح', style: TextStyle(color: AppColors.cream)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تم حفظ تقرير اليوم بنجاح.', style: TextStyle(color: AppColors.cream)),
            const SizedBox(height: 16),
            Text(
              isManager ? 'يمكنك الآن عرض التقرير التفصيلي لليوم.' : 'سيتم تسجيل الخروج الآن.',
              style: TextStyle(color: AppColors.creamMuted, fontSize: 13),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warmOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (isManager) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DailyReportPreviewScreen(report: report)),
                );
              } else {
                userCubit.logout();
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: Text(isManager ? 'عرض تقرير اليوم' : 'حسناً'),
          ),
        ],
      ),
    );
  }
}
