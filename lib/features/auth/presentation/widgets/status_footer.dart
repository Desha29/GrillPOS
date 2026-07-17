import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class StatusFooter extends StatelessWidget {
  const StatusFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedText = theme.colorScheme.onSurfaceVariant.withOpacity(0.5);
    final successColor = AppColors.successGreen;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'v1.0.2  Offline-First Mode  ',
          style: TextStyle(
            color: mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: .25,
          ),
        ),
        Text(
          '[🟢 Active]',
          style: TextStyle(
            color: successColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
