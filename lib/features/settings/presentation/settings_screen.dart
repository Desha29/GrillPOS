import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/security/permission_guard.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/presentation/cubit/user_cubit.dart';
import 'cubit/settings_cubit.dart';
import 'widgets/close_day_card.dart';
import 'widgets/data_management_card.dart';
import 'widgets/logout_warning_banner.dart';
import 'widgets/restaurant_info_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    final userCubit = getIt<UserCubit>();
    if (userCubit.allUsers.isEmpty) userCubit.getAllUsers();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<UserCubit>.value(value: getIt<UserCubit>()),
        BlocProvider<SettingsCubit>.value(value: getIt<SettingsCubit>()),
      ],
      child: const _SettingsScreenContent(),
    );
  }
}

class _SettingsScreenContent extends StatelessWidget {
  const _SettingsScreenContent();

  @override
  Widget build(BuildContext context) {
    final user = getIt<UserCubit>().currentUser;
    final isManager = user.userType == UserType.manager;
    final canManageData =
        PermissionGuard.can(user, AppPermission.backupRestore);
    final canCloseDay =
        PermissionGuard.can(user, AppPermission.closeBusinessDay);

    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < 640;
            final wide = constraints.maxWidth >= 980;
            final horizontalPadding = mobile ? AppSpacing.md : AppSpacing.lg;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.md,
                    horizontalPadding,
                    AppSpacing.xl,
                  ),
                  sliver: SliverList.list(
                    children: [
                      ScreenHeader(
                        title: 'الإعدادات',
                        subtitle: 'إدارة بيانات المطعم والجلسة وحماية البيانات',
                        icon: LucideIcons.settings2,
                        trailingWidget: mobile ? null : _UserBadge(user: user),
                      ),
                      if (mobile) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _UserBadge(user: user),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _SettingsIntroBanner(isManager: isManager),
                      const SizedBox(height: AppSpacing.md),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: RestaurantInfoCard(isMobile: mobile),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  if (canManageData) ...[
                                    DataManagementCard(isMobile: mobile),
                                    const SizedBox(height: AppSpacing.md),
                                  ],
                                  if (canCloseDay) ...[
                                    CloseDayCard(isMobile: mobile),
                                    const SizedBox(height: AppSpacing.md),
                                  ],
                                  LogoutWarningBanner(isMobile: mobile),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        RestaurantInfoCard(isMobile: mobile),
                        const SizedBox(height: AppSpacing.md),
                        if (canManageData) ...[
                          DataManagementCard(isMobile: mobile),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (canCloseDay) ...[
                          CloseDayCard(isMobile: mobile),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        LogoutWarningBanner(isMobile: mobile),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UserBadge extends StatelessWidget {
  const _UserBadge({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final isManager = user.userType == UserType.manager;
    final color = isManager ? AppColors.warmOrange : AppColors.blueMuted;
    final initial = user.name.trim().isEmpty ? '?' : user.name.trim()[0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: .13),
            child: Text(
              initial,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.name,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                isManager ? 'مدير النظام' : 'موظف كاشير',
                style: TextStyle(color: color, fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsIntroBanner extends StatelessWidget {
  const _SettingsIntroBanner({required this.isManager});

  final bool isManager;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [
            AppColors.warmOrange.withValues(alpha: .13),
            AppColors.warmOrange.withValues(alpha: .025),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.warmOrange.withValues(alpha: .22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.warmOrange.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.shieldCheck,
              color: AppColors.warmOrange,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isManager
                      ? 'لديك صلاحيات الإدارة الكاملة'
                      : 'إعدادات الجلسة الحالية',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isManager
                      ? 'يمكنك تحديث هوية المطعم وإدارة النسخ الاحتياطية وإغلاق الوردية.'
                      : 'يمكنك مراجعة معلومات المطعم وإدارة ورديتك الحالية.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
