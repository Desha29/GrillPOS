import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/components/app_logo.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../../core/functions/messege.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/cubit/user_cubit.dart';
import '../../../auth/presentation/cubit/user_states.dart';

class SidebarItem {
  SidebarItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.screen,
  });

  final String id;
  final IconData icon;
  final String title;
  final Widget screen;
}

class CustomSidebar extends StatefulWidget {
  const CustomSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  final List<SidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  @override
  State<CustomSidebar> createState() => _CustomSidebarState();
}

class _CustomSidebarState extends State<CustomSidebar> {
  List<Object> _groupedItems() {
    final entries = <Object>[];

    void addSection(String title, List<String> ids) {
      final sectionItems = widget.items
          .where((item) => ids.contains(item.id))
          .toList(growable: false);
      if (sectionItems.isEmpty) return;
      entries
        ..add(_SidebarSection(title))
        ..addAll(sectionItems);
    }

    addSection('HOME', const ['dashboard']);
    addSection('SERVICE', const ['pos', 'tables', 'orders']);
    addSection('MANAGEMENT', const ['menu', 'reports', 'users']);
    addSection('SYSTEM', const ['settings']);
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.isCollapsed ? 72.0 : 240.0;
    final narrow = widget.isCollapsed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: width,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: AppColors.sidebarGradient,
        border: Border(
          left: BorderSide(
            color: AppColors.borderColor.withValues(alpha: .65),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 24,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _SidebarHeader(
            narrow: narrow,
            collapsed: widget.isCollapsed,
            onToggle: widget.onToggleCollapse,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _groupedItems().length,
              itemBuilder: (context, index) {
                final entry = _groupedItems()[index];
                if (entry is _SidebarSection) {
                  return _SectionLabel(title: entry.title, narrow: narrow);
                }

                final item = entry as SidebarItem;
                final originalIndex = widget.items.indexOf(item);
                return _SidebarNavigationItem(
                  item: item,
                  narrow: narrow,
                  selected: widget.selectedIndex == originalIndex,
                  onTap: () => widget.onItemSelected(originalIndex),
                );
              },
            ),
          ),
          _SidebarFooter(
            narrow: narrow,
            onLogout: () => handleLogout(context),
          ),
        ],
      ),
    );
  }
}

class _SidebarSection {
  const _SidebarSection(this.title);

  final String title;
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.narrow,
    required this.collapsed,
    required this.onToggle,
  });

  final bool narrow;
  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: narrow ? 10 : 16),
        child: Row(
          mainAxisAlignment:
              narrow ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Tooltip(
              message: narrow ? 'Expand sidebar' : 'GrillPOS',
              child: InkWell(
                onTap: narrow ? onToggle : null,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: narrow ? 40 : 42,
                  height: narrow ? 40 : 42,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .75),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const AppLogo(width: 34, height: 34),
                ),
              ),
            ),
            if (!narrow) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'GrillPOS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.warmOrange,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .4,
                      ),
                ),
              ),
              if (onToggle != null)
                IconButton(
                  onPressed: onToggle,
                  tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    collapsed
                        ? LucideIcons.chevronRight
                        : LucideIcons.chevronLeft,
                    color: AppColors.creamMuted,
                    size: 20,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.narrow});

  final String title;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    if (narrow) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Divider(
          color: AppColors.borderColor.withValues(alpha: .6),
          indent: 8,
          endIndent: 8,
          height: 1,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 14,
        top: 14,
        bottom: 8,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.15,
            ),
      ),
    );
  }
}

class _SidebarNavigationItem extends StatefulWidget {
  const _SidebarNavigationItem({
    required this.item,
    required this.narrow,
    required this.selected,
    required this.onTap,
  });

  final SidebarItem item;
  final bool narrow;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarNavigationItem> createState() => _SidebarNavigationItemState();
}

class _SidebarNavigationItemState extends State<_SidebarNavigationItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.selected || _hovered;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Tooltip(
          message: widget.narrow ? widget.item.title : '',
          preferBelow: false,
          waitDuration: const Duration(milliseconds: 350),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 160),
            scale: _hovered && !widget.selected ? 1.018 : 1,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                hoverColor: Colors.transparent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  curve: Curves.easeOutCubic,
                  height: 48,
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.narrow ? 0 : 16,
                  ),
                  decoration: BoxDecoration(
                    color:
                        highlighted ? AppColors.warmOrange : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: widget.selected
                        ? Border.all(
                            color: Colors.white.withValues(alpha: .22),
                          )
                        : null,
                    boxShadow: widget.selected
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.warmOrange.withValues(alpha: .22),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: widget.narrow
                      ? Center(
                          child: Icon(
                            widget.item.icon,
                            color: highlighted
                                ? Colors.white
                                : AppColors.creamMuted,
                            size: 22,
                          ),
                        )
                      : Row(
                          children: [
                            Icon(
                              widget.item.icon,
                              color: highlighted
                                  ? Colors.white
                                  : AppColors.creamMuted,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                widget.item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: highlighted
                                          ? Colors.white
                                          : AppColors.creamMuted,
                                      fontSize: 14,
                                      fontWeight: highlighted
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                              ),
                            ),
                            if (widget.selected)
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.narrow,
    required this.onLogout,
  });

  final bool narrow;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
      child: Column(
        children: [
          BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, state) {
              final label = state.isDarkMode
                  ? 'Switch to light mode'
                  : 'Switch to dark mode';
              return _FooterAction(
                narrow: narrow,
                icon: state.isDarkMode ? LucideIcons.sun : LucideIcons.moon,
                label: label,
                color: AppColors.ember,
                backgroundColor: AppColors.ember.withValues(alpha: .06),
                onTap: () => context.read<ThemeCubit>().toggleTheme(),
              );
            },
          ),
          if (!narrow) ...[
            const SizedBox(height: 8),
            const _CurrentUserCard(),
          ],
          const SizedBox(height: 8),
          Divider(
            color: AppColors.borderColor.withValues(alpha: .7),
            height: 1,
          ),
          const SizedBox(height: 8),
          _FooterAction(
            narrow: narrow,
            icon: LucideIcons.logOut,
            label: 'Log out',
            color: AppColors.grillRed,
            backgroundColor: AppColors.grillRed.withValues(alpha: .06),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _CurrentUserCard extends StatelessWidget {
  const _CurrentUserCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserCubit, UserStates>(
      bloc: getIt<UserCubit>(),
      builder: (context, state) {
        final user = getIt<UserCubit>().currentUser;
        final manager = user.userType == UserType.manager;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.charcoalLight.withValues(alpha: .52),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: manager
                      ? AppColors.warmOrange.withValues(alpha: .16)
                      : AppColors.charcoalMedium,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: manager
                        ? AppColors.warmOrange.withValues(alpha: .35)
                        : AppColors.borderColor,
                  ),
                ),
                child: Text(
                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: manager
                            ? AppColors.warmOrange
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      manager ? 'Manager' : 'Cashier',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: manager
                                ? AppColors.warmOrange
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
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
}

class _FooterAction extends StatefulWidget {
  const _FooterAction({
    required this.narrow,
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final bool narrow;
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  State<_FooterAction> createState() => _FooterActionState();
}

class _FooterActionState extends State<_FooterAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.narrow ? widget.label : '',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 46,
              padding: EdgeInsets.symmetric(
                horizontal: widget.narrow ? 0 : 14,
              ),
              decoration: BoxDecoration(
                color: _hovered
                    ? widget.color.withValues(alpha: .12)
                    : widget.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: widget.narrow
                  ? Center(
                      child: Icon(widget.icon, color: widget.color, size: 20),
                    )
                  : Row(
                      children: [
                        Icon(widget.icon, color: widget.color, size: 20),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: widget.color,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
