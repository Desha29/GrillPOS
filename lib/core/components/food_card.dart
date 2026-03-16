import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../features/menu/data/menu_models.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class FoodCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;

  const FoodCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.charcoalLight,
      child: InkWell(
        onTap: item.isAvailable ? onTap : null,
        splashColor: AppColors.warmOrange.withOpacity(0.2),
        highlightColor: AppColors.warmOrange.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.charcoalLight,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppColors.borderColor.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section
              Expanded(
                flex: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.charcoalMedium,
                          child: Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.warmOrange),
                          ),
                        ),
                        errorWidget: (context, url, error) => _buildPlaceholder(),
                      )
                    else
                      _buildPlaceholder(),

                    // Gradient overlay at the bottom of the image
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Availability Overlay
                    if (!item.isAvailable)
                      Container(
                        color: Colors.black.withOpacity(0.6),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.grillRed,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'غير متوفر',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Details Section
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalLight,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppSpacing.cardRadius)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cream,
                          height: 1.3,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.price.toStringAsFixed(2)} ج.م',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.warmOrange,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: item.isAvailable ? AppColors.warmOrange.withOpacity(0.15) : AppColors.charcoalMedium,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: item.isAvailable ? AppColors.warmOrange.withOpacity(0.3) : AppColors.borderColor,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.add_shopping_cart,
                              size: 18,
                              color: item.isAvailable ? AppColors.warmOrange : AppColors.mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.charcoalMedium,
      child: Center(
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.charcoalLight,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderColor, width: 2),
          ),
          child: Center(
            child: Text(
              item.displayName.isNotEmpty
                  ? item.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.warmOrange,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
