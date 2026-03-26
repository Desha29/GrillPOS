// lib/features/dashboard/presentation/dashboard_screen.dart
import 'dart:ui' as ui;
import 'package:grill_pos/features/auth/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/constants/app_colors.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/functions/messege.dart';
import '../../../core/security/permission_guard.dart';
import '../../auth/presentation/cubit/user_cubit.dart';
import '../../auth/presentation/cubit/user_states.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../settings/presentation/cubit/settings_cubit.dart';
import '../../settings/presentation/cubit/settings_states.dart';
import '../../../core/theme/theme_cubit.dart';

import 'widgets/dashboard_home.dart';
import 'widgets/side_bar.dart';
import '../../pos/presentation/pos_screen.dart';
import '../../tables/presentation/tables_screen.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../menu/presentation/menu_management_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../auth/presentation/user_management_screen.dart';

import '../../reports/presentation/cubit/reports_cubit.dart';
import '../../reports/presentation/report_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;
  bool isSidebarCollapsed = false;

  late final User curUser = getIt<UserCubit>().currentUser;
  
  @override
  void initState() {
    super.initState();
  }

  List<SidebarItem> _getSidebarItems(BuildContext context) {
    return [
      SidebarItem(
        id: 'dashboard',
        icon: LucideIcons.layoutDashboard,
        title: "لوحة التحكم",
        screen: DashboardHome(
          onCardTap: (id) => handleCardTap(id),
          onOrderTap: (order) {
            handleCardTap('orders');
          },
          isManager: curUser.userType == UserType.manager,
        ),
      ),
      SidebarItem(
        id: 'pos',
        icon: LucideIcons.shoppingCart,
        title: "نقطة البيع",
        screen: const POSScreen(),
      ),
      SidebarItem(
        id: 'tables',
        icon: LucideIcons.grid,
        title: "الطاولات",
        screen: const TablesScreen(),
      ),
      SidebarItem(
        id: 'orders',
        icon: LucideIcons.receipt,
        title: "الطلبات",
        screen: const OrdersScreen(),
      ),
      SidebarItem(
        id: 'menu',
        icon: LucideIcons.bookOpen,
        title: "المنيو",
        screen: const MenuManagementScreen(),
      ),
      if (curUser.userType == UserType.manager)
        SidebarItem(
          id: 'reports',
          icon: LucideIcons.barChart3,
          title: "التقارير",
          screen: const ReportsScreen(),
        ),
      if (curUser.userType == UserType.manager)
        SidebarItem(
          id: 'users',
          icon: LucideIcons.shieldCheck,
          title: "المستخدمون",
          screen: const UserManagementScreen(),
        ),
      SidebarItem(
        id: 'settings',
        icon: LucideIcons.settings2,
        title: "الإعدادات",
        screen: const SettingsScreen(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sidebarItems = _getSidebarItems(context);
    final isMobileOrTablet = MediaQuery.of(context).size.width < 1000;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: MultiBlocListener(
        listeners: [
          BlocListener<UserCubit, UserStates>(
            bloc: getIt<UserCubit>(),
            listener: (context, state) {
              if (state is CloseSessionLoading) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (c) => Center(
                    child: CircularProgressIndicator(color: AppColors.warmOrange),
                  ),
                );
              } else if (state is UserSuccessWithReport) {
                // Ensure we pop the loading dialog if it's there
                Navigator.of(context, rootNavigator: true).pop();
                
                final userCubit = getIt<UserCubit>();
                if (userCubit.currentUser.userType == UserType.manager) {
                  _showShiftReport(context, state.report as String);
                } else {
                  MotionSnackBarSuccess(context, "تم إغلاق اليوم بنجاح. جاري تسجيل الخروج...");
                  Future.delayed(const Duration(milliseconds: 1500), () {
                    userCubit.logout();
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  });
                }
              } else if (state is UserFailure) {
                // Pop the loading dialog on failure
                if (Navigator.of(context, rootNavigator: true).canPop()) {
                  // This is a bit risky but we check for failure during session close
                  // Usually if we are in CloseSessionLoading, we know a dialog is open
                  Navigator.of(context, rootNavigator: true).pop();
                }
                MotionSnackBarError(context, state.error);
              }
            },
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, themeState) {
            return Scaffold(
              key: ValueKey(themeState.isDarkMode),
              appBar: isMobileOrTablet
                  ? AppBar(
                      backgroundColor: AppColors.charcoalMedium,
                      title: BlocBuilder<SettingsCubit, SettingsStates>(
                          bloc: getIt<SettingsCubit>(),
                          builder: (context, state) {
                            final name = getIt<SettingsCubit>()
                                    .currentRestaurantInfo
                                    ?.name ??
                                'GrillPOS';
                            return Text(name.isNotEmpty ? name : 'GrillPOS');
                          }),
                      leading: Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(LucideIcons.menu),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                    )
                  : null,
              drawer: isMobileOrTablet
                  ? Drawer(
                      child: CustomSidebar(
                        items: sidebarItems,
                        selectedIndex: selectedIndex,
                        onItemSelected: (index) =>
                            _onSidebarSelected(context, index),
                      ),
                    )
                  : null,
              body: Row(
                children: [
                  if (!isMobileOrTablet)
                    CustomSidebar(
                      items: sidebarItems,
                      selectedIndex: selectedIndex,
                      isCollapsed: isSidebarCollapsed,
                      onItemSelected: (index) =>
                          _onSidebarSelected(context, index),
                      onToggleCollapse: () {
                        setState(() {
                          isSidebarCollapsed = !isSidebarCollapsed;
                        });
                      },
                    ),
                  Expanded(
                    child: Container(
                      color: AppColors.charcoalDark,
                      child: sidebarItems[selectedIndex].screen,
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

  void _onSidebarSelected(BuildContext context, int index) {
    final sidebarItems = _getSidebarItems(context);
    final item = sidebarItems[index];
    if (item.id == 'reports') {
      try {
        PermissionGuard.checkReportAccess(curUser);
      } catch (e) {
        MotionSnackBarError(context, e.toString());
        return;
      }
    }

    setState(() {
      selectedIndex = index;
    });

    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  void handleCardTap(String id) {
    final sidebarItems = _getSidebarItems(context);
    final index = sidebarItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      _onSidebarSelected(context, index);
    } else {
      MotionSnackBarWarning(context, "الشاشة غير متاحة");
    }
  }

  void _showShiftReport(BuildContext context, String shiftId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ShiftReportDialog(shiftId: shiftId),
    );
  }
}

class _ShiftReportDialog extends StatelessWidget {
  final String shiftId;
  const _ShiftReportDialog({required this.shiftId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCircle2, color: AppColors.successGreen, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'تم إغلاق الوردية بنجاح',
              style: TextStyle(color: AppColors.cream, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'ملخص الوردية الحالية',
              style: TextStyle(color: AppColors.mutedColor, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.charcoalMedium,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  _reportRow('رقم الوردية', shiftId.substring(0, 8).toUpperCase()),
                  const Divider(height: 24),
                  _reportRow('الحالة', 'مغلقة'),
                  _reportRow('الوقت', DateFormat('HH:mm').format(DateTime.now())),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warmOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('موافق', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                // Get summary for today for the detailed view
                final reportsCubit = getIt<ReportsCubit>();
                reportsCubit.load(filter: ReportFilter.today).then((_) {
                  final state = reportsCubit.state;
                  if (state.summary != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportDetailsScreen(
                          summary: state.summary!,
                          topItems: state.topItems,
                          reportTitle: 'تقرير الوردية الحالية',
                        ),
                      ),
                    );
                  }
                });
              },
              icon: const Icon(LucideIcons.fileText, size: 16),
              label: const Text('عرض التقرير التفصيلي'),
              style: TextButton.styleFrom(foregroundColor: AppColors.warmOrange),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.mutedColor, fontSize: 14)),
          Text(value, style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
