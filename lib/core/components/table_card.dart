import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../features/tables/data/table_models.dart';
import '../constants/app_colors.dart';

class TableCard extends StatefulWidget {
  const TableCard({
    super.key,
    required this.table,
    required this.onTap,
  });

  final RestaurantTable table;
  final VoidCallback onTap;

  @override
  State<TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<TableCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(widget.table.status);
    final occupied = widget.table.currentOrderId != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.012 : 1,
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _hovered
                      ? color.withValues(alpha: .62)
                      : widget.table.status == TableStatus.available
                          ? AppColors.borderColor
                          : color.withValues(alpha: .34),
                  width: _hovered ? 1.4 : 1,
                ),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: .10),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _statusIcon(widget.table.status),
                          color: color,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.table.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'رقم ${widget.table.tableNumber}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.chevronLeft,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _InfoPill(
                        label: widget.table.status.displayName,
                        icon: _statusIcon(widget.table.status),
                        color: color,
                      ),
                      _InfoPill(
                        label: '${widget.table.capacity} مقاعد',
                        icon: LucideIcons.usersRound,
                        color: AppColors.blueMuted,
                      ),
                      _InfoPill(
                        label: widget.table.section,
                        icon: LucideIcons.mapPin,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: occupied
                          ? AppColors.grillRed.withValues(alpha: .07)
                          : AppColors.charcoalLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: occupied
                            ? AppColors.grillRed.withValues(alpha: .22)
                            : AppColors.borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          occupied
                              ? LucideIcons.receiptText
                              : LucideIcons.sparkles,
                          size: 16,
                          color: occupied ? AppColors.grillRed : color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            occupied
                                ? 'طلب نشط: ${_shortOrder(widget.table.currentOrderId!)}'
                                : _statusHint(widget.table.status),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: occupied
                                ? TextDirection.ltr
                                : TextDirection.rtl,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(TableStatus status) => switch (status) {
      TableStatus.available => AppColors.successGreen,
      TableStatus.occupied => AppColors.grillRed,
      TableStatus.reserved => AppColors.warmOrange,
      TableStatus.cleaning => AppColors.blueMuted,
    };

IconData _statusIcon(TableStatus status) => switch (status) {
      TableStatus.available => LucideIcons.circleCheck,
      TableStatus.occupied => LucideIcons.utensils,
      TableStatus.reserved => LucideIcons.calendarClock,
      TableStatus.cleaning => LucideIcons.sparkles,
    };

String _statusHint(TableStatus status) => switch (status) {
      TableStatus.available => 'جاهزة لاستقبال طلب جديد',
      TableStatus.occupied => 'مشغولة بدون رقم طلب ظاهر',
      TableStatus.reserved => 'محجوزة لضيف أو موعد قادم',
      TableStatus.cleaning => 'قيد التجهيز والتنظيف',
    };

String _shortOrder(String id) =>
    id.length <= 12 ? id : '${id.substring(0, 8)}…';
