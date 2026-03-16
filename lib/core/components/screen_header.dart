// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'anim_wrappers.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double fontSize;
  final IconData? icon;
  final Color? titleColor;
  final Color? iconColor;
  final Color? subtitleColor;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingPressed;
  final VoidCallback? onBackPressed;

  const ScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.fontSize = 28,
    this.icon,
    this.titleColor,
    this.subtitleColor,
    this.iconColor,
    this.trailingIcon,
    this.onTrailingPressed,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    final adaptiveFontSize = screenWidth < 600
        ? fontSize * 0.75
        : screenWidth < 900
            ? fontSize * 0.85
            : fontSize;

    final adaptiveSubtitleSize = screenWidth < 600 ? 13.0 : 14.0;

    return FadeSlideIn(
      beginOffset: const Offset(0, 0.15),
      duration: const Duration(milliseconds: 600),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: screenWidth > 768 ? 14 : 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Back button
            if (onBackPressed != null) ...[
              Material(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onBackPressed,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back, color: AppColors.cream, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            // Icon
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.warmOrange).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppColors.warmOrange,
                  size: adaptiveFontSize * 0.7,
                ),
              ),
              SizedBox(width: screenWidth > 768 ? 14 : 10),
            ],
            // Title & Subtitle
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: titleColor ?? AppColors.cream,
                        fontSize: adaptiveFontSize,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: subtitleColor ?? AppColors.creamMuted,
                      fontSize: adaptiveSubtitleSize,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            // Trailing action
            if (trailingIcon != null)
              Material(
                color: (iconColor ?? AppColors.warmOrange).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onTrailingPressed,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      trailingIcon,
                      color: iconColor ?? AppColors.warmOrange,
                      size: 22,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
