import 'package:flutter/material.dart';

import '../../../features/tables/data/table_models.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class TableCard extends StatefulWidget {
  final RestaurantTable table;
  final VoidCallback onTap;

  const TableCard({
    super.key,
    required this.table,
    required this.onTap,
  });

  @override
  State<TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<TableCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;
    switch (widget.table.status) {
      case TableStatus.available:
        statusColor = AppColors.successGreen;
        statusBgColor = AppColors.successGreen.withOpacity(0.1);
        statusIcon = Icons.restaurant;
        break;
      case TableStatus.occupied:
        statusColor = AppColors.grillRed;
        statusBgColor = AppColors.grillRed.withOpacity(0.1);
        statusIcon = Icons.person;
        break;
      case TableStatus.reserved:
        statusColor = AppColors.ember;
        statusBgColor = AppColors.ember.withOpacity(0.1);
        statusIcon = Icons.event_available;
        break;
      case TableStatus.cleaning:
        statusColor = AppColors.warningColor;
        statusBgColor = AppColors.warningColor.withOpacity(0.1);
        statusIcon = Icons.cleaning_services;
        break;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: _isHovered
                    ? statusColor
                    : (widget.table.status != TableStatus.available
                        ? statusColor.withOpacity(0.5)
                        : AppColors.borderColor),
                width: widget.table.status != TableStatus.available ? 2 : (_isHovered ? 2 : 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? statusColor.withOpacity(0.2)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: _isHovered ? 15 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 28),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.table.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 14, color: AppColors.mutedColor),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.table.capacity} مقاعد',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.creamMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    widget.table.status.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
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
