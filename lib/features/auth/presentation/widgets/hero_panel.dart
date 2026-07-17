import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        // Added your new background image here
        image: DecorationImage(
          image: const AssetImage(
              'assets/images/grillpos/login_bg.png'), // Ensure this matches your file name
          fit: BoxFit.cover,
          // A subtle darkening filter ensures the white text and logo pop perfectly
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.3),
            BlendMode.darken,
          ),
        ),
      ),
      child: Stack(
        children: [
          // Subtle grid watermark behind content
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(color: primary),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    isDark
                        ? 'assets/images/grillpos/logo_full.png'
                        : 'assets/images/grillpos/logo_full_l.png',
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.local_fire_department_rounded,
                      size: 100,
                      color: primary,
                    ),
                  )
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.easeOutBack)
                      .fadeIn(),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Grill POS',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                      // Forced white color for contrast against the warm gradient
                      color: Colors.white,
                    ),
                  ).animate().slideY(begin: 0.2, duration: 600.ms).fadeIn(),
                  const SizedBox(height: 8),
                  Text(
                    'Fast, Reliable & Offline-First POS',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      // Forced off-white for contrast
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ).animate().slideY(begin: 0.3, duration: 700.ms).fadeIn(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.015)
      ..strokeWidth = 1;
    const step = 60.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
