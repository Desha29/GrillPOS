import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grill_pos/core/components/screen_header.dart';
import 'package:grill_pos/core/constants/app_colors.dart';
import 'package:grill_pos/features/auth/presentation/cubit/user_cubit.dart';

import 'package:grill_pos/features/settings/presentation/cubit/settings_cubit.dart';
import '../../../core/di/dependency_injection.dart';

import '../../auth/data/models/user_model.dart';

import 'widgets/logout_warning_banner.dart';
import 'widgets/close_day_card.dart';

import 'widgets/data_management_card.dart';
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
    if (userCubit.allUsers.isEmpty) {
      userCubit.getAllUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<UserCubit>.value(value: getIt<UserCubit>()),
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
      body: SafeArea(
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
                        if (getIt<UserCubit>().currentUser.userType ==
                            UserType.manager) ...[
                          DataManagementCard(isMobile: isMobile),
                          SizedBox(height: isMobile ? 12 : 16),
                        ],
                        RestaurantInfoCard(isMobile: isMobile),
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
    );
  }
}
