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
    final theme = Theme.of(context);

    if (loading && users.isEmpty) {
      return SizedBox(
        height: 106,
        child: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
            strokeWidth: 2.5,
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
    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final user = users[index];
          return SizedBox(
            width: 230,
            child: QuickUserCard(
              user: user,
              selected: selectedUser?.username == user.username,
              onTap: () => onSelected(user),
            ),
          );
        },
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
      height: 106,
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
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class QuickUserCard extends StatefulWidget {
  const QuickUserCard({
    super.key,
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final User user;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<QuickUserCard> createState() => _QuickUserCardState();
}

class _QuickUserCardState extends State<QuickUserCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final manager = widget.user.userType == UserType.manager;

    final Color cardColor = widget.selected
        ? theme.colorScheme.primary.withOpacity(0.08)
        : (_hovered 
            ? theme.colorScheme.primary.withOpacity(0.04)
            : (isDark 
                ? theme.colorScheme.surfaceContainerHighest 
                : theme.colorScheme.surfaceContainerLowest));

    final Color borderColor = widget.selected
        ? theme.colorScheme.primary
        : (_hovered
            ? theme.colorScheme.primary.withOpacity(0.4)
            : theme.colorScheme.outlineVariant.withOpacity(0.3));

    return Semantics(
      button: true,
      selected: widget.selected,
      label: '${widget.user.name}, ${manager ? 'Manager' : 'Cashier'}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: widget.selected ? 2.0 : 1.0,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${manager ? '🔥' : '🍔'} ${widget.user.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      manager ? 'Manager' : 'Cashier',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      manager ? '🟢 PIN Required' : '🍔 Ready',
                      maxLines: 1,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
