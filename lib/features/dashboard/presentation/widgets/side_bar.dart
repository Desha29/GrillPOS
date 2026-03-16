// ignore_for_file: deprecated_member_use
import 'package:grill_pos/core/functions/messege.dart';
import 'package:grill_pos/features/auth/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/components/app_logo.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../auth/presentation/cubit/user_cubit.dart';
import '../../../auth/presentation/cubit/user_states.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_states.dart';

class SidebarItem {
  final String id;
  final IconData icon;
  final String title;
  final Widget screen;
  SidebarItem(
      {required this.id,
      required this.icon,
      required this.title,
      required this.screen});
}

class CustomSidebar extends StatefulWidget {
  final List<SidebarItem> items;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const CustomSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  @override
  State<CustomSidebar> createState() => _CustomSidebarState();
}

class _CustomSidebarState extends State<CustomSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;
  int _hoveredIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _widthAnimation = Tween<double>(
      begin: 240,
      end: 70,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.isCollapsed) _controller.forward();
  }

  @override
  void didUpdateWidget(CustomSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final w = _widthAnimation.value.clamp(56.0, 320.0);
        final compact = w < 100;

        return Container(
          width: w,
          decoration: BoxDecoration(
            gradient: AppColors.sidebarGradient,
            border: Border(
              left: BorderSide(color: AppColors.borderColor, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Logo & store name
              SizedBox(
                height: compact ? 60 : 90,
                child: Center(
                  child: _SidebarHeader(compact: compact, maxW: w),
                ),
              ),
              const SizedBox(height: 8),

              // Current user card
              if (!compact) _buildUserCard(),
              if (!compact) const SizedBox(height: 8),

              // Collapse toggle
              if (widget.onToggleCollapse != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: IconButton(
                    icon: Icon(
                      widget.isCollapsed ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
                      color: AppColors.mutedColor,
                      size: 18,
                    ),
                    tooltip: widget.isCollapsed ? 'توسيع القائمة' : 'تصغير القائمة',
                    onPressed: widget.onToggleCollapse,
                  ),
                ),
              const SizedBox(height: 4),

              // Nav items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final isSelected = index == widget.selectedIndex;
                    final isHovered = index == _hoveredIndex;

                    final bgColor = isSelected
                        ? AppColors.warmOrange.withOpacity(0.15)
                        : isHovered
                            ? AppColors.charcoalLight.withOpacity(0.4)
                            : Colors.transparent;

                    final fgIcon = isSelected
                        ? AppColors.warmOrange
                        : AppColors.mutedColor;

                    final titleStyle = TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? AppColors.warmOrange
                          : AppColors.creamMuted,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    );

                    return MouseRegion(
                      onEnter: (_) => setState(() => _hoveredIndex = index),
                      onExit: (_) => setState(() => _hoveredIndex = -1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: AppColors.warmOrange.withOpacity(0.2))
                              : null,
                        ),
                        child: ListTile(
                          dense: true,
                          horizontalTitleGap: 10,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          leading: Icon(item.icon, size: 20, color: fgIcon),
                          title: w > 100
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    item.title,
                                    style: titleStyle,
                                  ),
                                )
                              : null,
                          onTap: () => widget.onItemSelected(index),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Logout
              Divider(
                color: AppColors.borderColor,
                height: 1,
                thickness: 0.5,
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  LucideIcons.logOut,
                  color: AppColors.grillRed,
                  size: 20,
                ),
                title: w > 100
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          "تسجيل الخروج",
                          style: TextStyle(
                            color: AppColors.grillRed,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : null,
                onTap: () {
                  handleLogout(context);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserCard() {
    return BlocBuilder<UserCubit, UserStates>(
      bloc: getIt<UserCubit>(),
      builder: (context, state) {
        final currentUser = getIt<UserCubit>().currentUser;
        final isManager = currentUser.userType == UserType.manager;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isManager ? AppColors.warmOrange.withOpacity(0.2) : AppColors.charcoalLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isManager ? AppColors.warmOrange.withOpacity(0.4) : AppColors.borderColor,
                  ),
                ),
                child: Center(
                  child: Text(
                    currentUser.name.isNotEmpty ? currentUser.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isManager ? AppColors.warmOrange : AppColors.cream,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cream,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isManager ? 'مدير' : 'كاشير',
                      style: TextStyle(
                        fontSize: 11,
                        color: isManager ? AppColors.ember : AppColors.mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.compact, required this.maxW});

  final bool compact;
  final double maxW;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 18.0 : 28.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FittedBox(
            child: SizedBox(
              height: radius * 2.5,
              width: radius * 2.5,
              child: ClipOval(
                child: AppLogo(width: 140, height: 140, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BlocBuilder<SettingsCubit, SettingsStates>(
                      bloc: getIt<SettingsCubit>(),
                      builder: (context, state) {
                        final name =
                            getIt<SettingsCubit>().currentStoreInfo?.name ??
                                'GrillPOS';
                        return Text(
                          name.isNotEmpty ? name : 'GrillPOS',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.cream,
                                    fontSize: 15,
                                    height: 1.2,
                                  ),
                        );
                      }),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
