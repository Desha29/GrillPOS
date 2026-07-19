// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../features/menu/data/menu_models.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../services/product_image_storage.dart';

class FoodCard extends StatefulWidget {
  const FoodCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final MenuItem item;
  final VoidCallback onTap;

  @override
  State<FoodCard> createState() => _FoodCardState();
}

class _FoodCardState extends State<FoodCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: item.isAvailable
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        scale: _hovered && item.isAvailable ? 1.018 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: AppColors.charcoalMedium,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: _hovered && item.isAvailable
                  ? AppColors.warmOrange.withOpacity(.55)
                  : AppColors.borderColor,
            ),
            boxShadow: _hovered && item.isAvailable
                ? [
                    BoxShadow(
                      color: AppColors.warmOrange.withOpacity(.12),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : AppColors.isDarkMode
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: item.isAvailable ? widget.onTap : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ProductImageView(
                          source: item.imageUrl,
                          semanticLabel: 'صورة ${item.displayName}',
                          placeholder:
                              const ProductImagePlaceholder(iconSize: 40),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x66000000)],
                              stops: [.58, 1],
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          top: 8,
                          end: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: item.isAvailable
                                  ? AppColors.successGreen.withOpacity(.92)
                                  : AppColors.grillRed.withOpacity(.92),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.isAvailable
                                      ? Icons.check_circle_rounded
                                      : Icons.block_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  item.isAvailable ? 'متاح' : 'غير متاح',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (item.unit?.trim().isNotEmpty == true)
                          PositionedDirectional(
                            start: 8,
                            bottom: 7,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(.58),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                item.unit!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: item.isAvailable
                                ? AppColors.cream
                                : AppColors.creamMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: item.price.toStringAsFixed(2),
                                      style: TextStyle(
                                        color: item.isAvailable
                                            ? AppColors.warmOrange
                                            : AppColors.mutedColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' ج.م',
                                      style: TextStyle(
                                        color: AppColors.creamMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 29,
                              height: 29,
                              decoration: BoxDecoration(
                                color: item.isAvailable
                                    ? AppColors.warmOrange
                                    : AppColors.charcoalLight,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                item.isAvailable
                                    ? Icons.add_rounded
                                    : Icons.lock_outline_rounded,
                                size: 18,
                                color: item.isAvailable
                                    ? Colors.white
                                    : AppColors.mutedColor,
                              ),
                            ),
                          ],
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
