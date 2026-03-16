import 'package:flutter/material.dart';

import '../../../features/orders/data/order_models.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class CartItemWidget extends StatelessWidget {
  final OrderItem item;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onDelete;
  final VoidCallback onAddNote;

  const CartItemWidget({
    super.key,
    required this.item,
    required this.onAdd,
    required this.onRemove,
    required this.onDelete,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cream,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.unitPrice.toStringAsFixed(2)} ج.م',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.creamMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.subtotal.toStringAsFixed(2)} ج.م',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.warmOrange,
                ),
              ),
            ],
          ),
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.ember.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_alt_outlined, size: 12, color: AppColors.ember),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.notes!,
                      style: TextStyle(fontSize: 12, color: AppColors.ember),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _QuantityButton(
                    icon: Icons.remove,
                    onPressed: item.quantity > 1 ? onRemove : onDelete,
                    isDanger: item.quantity <= 1,
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '${item.quantity}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.cream,
                      ),
                    ),
                  ),
                  _QuantityButton(
                    icon: Icons.add,
                    onPressed: onAdd,
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_note, color: AppColors.mutedColor, size: 22),
                    onPressed: onAddNote,
                    tooltip: 'إضافة ملاحظة',
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: AppColors.grillRed, size: 22),
                    onPressed: onDelete,
                    tooltip: 'حذف من الفاتورة',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDanger;

  const _QuantityButton({
    required this.icon,
    required this.onPressed,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDanger ? AppColors.grillRed.withAlpha(25) : AppColors.charcoalLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDanger ? AppColors.grillRed.withAlpha(127) : AppColors.borderColor,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDanger ? AppColors.grillRed : AppColors.cream,
        ),
      ),
    );
  }
}
