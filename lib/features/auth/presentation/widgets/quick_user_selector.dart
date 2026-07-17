import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';

class QuickUserSelector extends StatelessWidget {
  const QuickUserSelector({
    super.key,
    required this.users,
    required this.selectedUser,
    required this.loading,
    required this.error,
    required this.onSelected,
    required this.onRetry,
  });

  final List<User> users;
  final User? selectedUser;
  final bool loading;
  final String? error;
  final ValueChanged<User> onSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading && users.isEmpty) {
      return const SizedBox(
        height: 62,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (users.isEmpty) {
      return QuickUsersMessage(
        message: error ?? 'No active users are available.',
        actionLabel: error == null ? 'Refresh' : 'Retry',
        onAction: onRetry,
      );
    }

    // Compact horizontal scrollable user chips
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final user = users[index];
          final isSelected = selectedUser?.username == user.username;
          final manager = user.userType == UserType.manager;

          return _CompactUserChip(
            user: user,
            selected: isSelected,
            manager: manager,
            onTap: () => onSelected(user),
          );
        },
      ),
    );
  }
}

class _CompactUserChip extends StatefulWidget {
  const _CompactUserChip({
    required this.user,
    required this.selected,
    required this.manager,
    required this.onTap,
  });

  final User user;
  final bool selected;
  final bool manager;
  final VoidCallback onTap;

  @override
  State<_CompactUserChip> createState() => _CompactUserChipState();
}

class _CompactUserChipState extends State<_CompactUserChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final Color bgColor = widget.selected
        ? primary.withOpacity(0.12)
        : (_hovered
            ? primary.withOpacity(0.06)
            : (isDark
                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
                : theme.colorScheme.surfaceContainerLowest));

    final Color borderColor = widget.selected
        ? primary
        : (_hovered
            ? primary.withOpacity(0.35)
            : theme.colorScheme.outlineVariant.withOpacity(0.3));

    return Semantics(
      button: true,
      selected: widget.selected,
      label: '${widget.user.name}, ${widget.manager ? 'Manager' : 'Cashier'}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: borderColor,
                width: widget.selected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar circle
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.selected
                        ? primary.withOpacity(0.15)
                        : theme.colorScheme.surfaceContainerHighest
                            .withOpacity(isDark ? 0.6 : 0.5),
                    gradient: widget.user.userType == UserType.manager
                        ? LinearGradient(
                            colors: [Colors.red, Colors.orange],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      widget.manager ? 'M' : 'C',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name & role
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.manager ? 'Manager' : 'Cashier',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.65),
                        height: 1.2,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (widget.selected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle_rounded, size: 18, color: primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuickUsersMessage extends StatelessWidget {
  const QuickUsersMessage({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
