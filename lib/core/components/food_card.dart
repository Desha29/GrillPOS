import 'package:flutter/material.dart';
import '../../../features/menu/data/menu_models.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class FoodCard extends StatefulWidget {
  final MenuItem item;
  final VoidCallback onTap;

  const FoodCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<FoodCard> createState() => _FoodCardState();
}

class _FoodCardState extends State<FoodCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
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
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          if (widget.item.isAvailable) widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: AppColors.charcoalLight,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? AppColors.warmOrange.withOpacity(0.15)
                      : Colors.black.withOpacity(0.12),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: Offset(0, _isHovered ? 6 : 3),
                ),
              ],
              border: Border.all(
                color: _isHovered
                    ? AppColors.warmOrange.withOpacity(0.4)
                    : AppColors.borderColor.withOpacity(0.5),
                width: _isHovered ? 1.5 : 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Responsive font sizing based on card width
                final double titleFontSize = constraints.maxWidth > 150 ? 20 : 16;
                final double priceFontSize = constraints.maxWidth > 150 ? 16 : 14;

                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            widget.item.displayName,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cream,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.item.isAvailable 
                              ? AppColors.warmOrange.withOpacity(0.15)
                              : AppColors.charcoalMedium,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.item.price.toStringAsFixed(2)} ج.م',
                          style: TextStyle(
                            fontSize: priceFontSize,
                            fontWeight: FontWeight.w900,
                            color: widget.item.isAvailable 
                                ? AppColors.warmOrange
                                : AppColors.mutedColor,
                          ),
                        ),
                      ),
                      if (!widget.item.isAvailable) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.grillRed.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'غير متوفر',
                            style: TextStyle(
                              color: AppColors.grillRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }
            ),
          ),
        ),
      ),
    );
  }
}
