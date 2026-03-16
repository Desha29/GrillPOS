import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';


enum _POSButtonType { primary, danger, success, ghost }

class POSButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isGhost;
  final bool isExpanded;
  final double? width;
  final double? height;
  final _POSButtonType _type;

  const POSButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.isGhost = false,
    this.isExpanded = false,
    this.width,
    this.height = AppSpacing.posButtonSize,
  }) : _type = _POSButtonType.primary;

  POSButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.isGhost = false,
    this.isExpanded = false,
    this.width,
    this.height = AppSpacing.posButtonSize,
  }) : _type = _POSButtonType.danger;

  POSButton.success({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.isGhost = false,
    this.isExpanded = false,
    this.width,
    this.height = AppSpacing.posButtonSize,
  }) : _type = _POSButtonType.success;

  const POSButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor = Colors.transparent,
    this.foregroundColor,     // Default will be handled in build
    this.isGhost = true,
    this.isExpanded = false,
    this.width,
    this.height = AppSpacing.posButtonSize,
  }) : _type = _POSButtonType.ghost;

  @override
  State<POSButton> createState() => _POSButtonState();
}

class _POSButtonState extends State<POSButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
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

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    // Resolve effective colors
    Color effectiveBg;
    Color effectiveFg;

    switch (widget._type) {
      case _POSButtonType.danger:
        effectiveBg = widget.backgroundColor ?? AppColors.grillRed;
        effectiveFg = widget.foregroundColor ?? Colors.white;
        break;
      case _POSButtonType.success:
        effectiveBg = widget.backgroundColor ?? AppColors.successGreen;
        effectiveFg = widget.foregroundColor ?? Colors.white;
        break;
      case _POSButtonType.ghost:
        effectiveBg = widget.backgroundColor ?? Colors.transparent;
        effectiveFg = widget.foregroundColor ?? AppColors.warmOrange;
        break;
      case _POSButtonType.primary:
      effectiveBg = widget.backgroundColor ?? AppColors.warmOrange;
        effectiveFg = widget.foregroundColor ?? Colors.white;
        break;
    }

    Widget buttonContent = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onPressed,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.isExpanded ? double.infinity : widget.width,
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: widget.isGhost
                  ? (_isHovered ? effectiveFg.withOpacity(0.1) : effectiveBg)
                  : (_isHovered
                      ? Color.lerp(effectiveBg, Colors.white, 0.1)
                      : effectiveBg),
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              border: widget.isGhost ? Border.all(color: effectiveFg, width: 2) : null,
              boxShadow: widget.isGhost
                  ? []
                  : [
                      BoxShadow(
                        color: effectiveBg.withOpacity(_isHovered ? 0.4 : 0.2),
                        blurRadius: _isHovered ? 12 : 6,
                        offset: Offset(0, _isHovered ? 4 : 2),
                      )
                    ],
            ),
            child: Row(
              mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: effectiveFg, size: 22),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: effectiveFg,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return widget.isExpanded
        ? Expanded(child: buttonContent)
        : buttonContent;
  }
}
