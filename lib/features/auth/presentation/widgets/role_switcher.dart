import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';

class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher({
    super.key,
    required this.selectedRole,
    required this.onSelected,
  });

  final UserType selectedRole;
  final ValueChanged<UserType> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark 
            ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(isDark ? 0.3 : 0.6),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RoleOption(
              label: 'Cashier',
              icon: Icons.point_of_sale_rounded,
              selected: selectedRole == UserType.cashier,
              onTap: () => onSelected(UserType.cashier),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _RoleOption(
              label: 'Manager',
              icon: Icons.admin_panel_settings_rounded,
              selected: selectedRole == UserType.manager,
              onTap: () => onSelected(UserType.manager),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color selectedBg = theme.colorScheme.primary;
    
    // Inactive tab background as shown in the screenshot
    final Color unselectedBg = isDark
        ? theme.colorScheme.surface.withOpacity(0.3)
        : const Color(0xFFF1F2F4);

    final Color selectedColor = theme.colorScheme.onPrimary;
    final Color unselectedColor = isDark
        ? theme.colorScheme.onSurfaceVariant.withOpacity(0.8)
        : const Color(0xFF4A4D54);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? selectedBg : unselectedBg,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? selectedColor : unselectedColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? selectedColor : unselectedColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
