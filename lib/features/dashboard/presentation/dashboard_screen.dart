// lib/features/dashboard/presentation/dashboard_screen.dart
import 'package:grill_pos/features/auth/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/functions/messege.dart';
import '../../../core/security/permission_guard.dart';
import '../../auth/presentation/cubit/user_cubit.dart';
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
      textDirection: TextDirection.rtl,
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

  /// Handles tap on a card in the dashboard screen.
  void handleCardTap(String id) {
    final sidebarItems = _getSidebarItems(context);
    final index = sidebarItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      _onSidebarSelected(context, index);
    } else {
      MotionSnackBarWarning(context, "الشاشة غير متاحة");
    }
  }
}
