import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/auth/presentation/cubit/user_cubit.dart';
import '../constants/app_colors.dart';
import '../di/dependency_injection.dart';

enum AppMessageType { success, error, warning, info }

/// Backward-compatible entry points used throughout the existing application.
/// All flows now render the same professional, accessible notification card.
void MotionSnackBarSuccess(BuildContext context, String message) =>
    AppMessage.show(context, message, type: AppMessageType.success);

void MotionSnackBarError(BuildContext context, String message) =>
    AppMessage.show(context, message, type: AppMessageType.error);

void MotionSnackBarInfo(BuildContext context, String message) =>
    AppMessage.show(context, message, type: AppMessageType.info);

void MotionSnackBarWarning(BuildContext context, String message) =>
    AppMessage.show(context, message, type: AppMessageType.warning);

class AppMessage {
  AppMessage._();

  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context,
    String message, {
    AppMessageType type = AppMessageType.info,
    String? title,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? action,
    String? actionLabel,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || message.trim().isEmpty) return;

    dismiss();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _MessagePlacement(
        child: _ProfessionalMessageCard(
          type: type,
          title: title ?? _defaultTitle(type),
          message: message.trim(),
          duration: duration,
          action: action,
          actionLabel: actionLabel,
          onClose: () {
            if (identical(_activeEntry, entry)) dismiss();
          },
        ),
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }

  static String _defaultTitle(AppMessageType type) => switch (type) {
        AppMessageType.success => 'تمت العملية بنجاح',
        AppMessageType.error => 'تعذر إكمال العملية',
        AppMessageType.warning => 'تنبيه مهم',
        AppMessageType.info => 'إشعار',
      };
}

class _MessagePlacement extends StatelessWidget {
  const _MessagePlacement({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SafeArea(
      minimum: EdgeInsets.fromLTRB(16, width < 600 ? 12 : 20, 16, 16),
      child: Align(
        alignment: width < 600 ? Alignment.topCenter : Alignment.topRight,
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }
}

class _ProfessionalMessageCard extends StatelessWidget {
  const _ProfessionalMessageCard({
    required this.type,
    required this.title,
    required this.message,
    required this.duration,
    required this.onClose,
    this.action,
    this.actionLabel,
  });

  final AppMessageType type;
  final String title;
  final String message;
  final Duration duration;
  final VoidCallback onClose;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final color = _messageColor(type);
    final icon = _messageIcon(type);
    final width = MediaQuery.sizeOf(context).width;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset((1 - value) * 36, 0),
          child: child,
        ),
      ),
      child: Container(
        width: width < 600 ? width - 32 : 390,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.charcoalMedium,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: .34)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: color.withValues(alpha: .08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: color),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 12, 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (action != null && actionLabel != null) ...[
                          const SizedBox(height: 9),
                          TextButton(
                            onPressed: () {
                              onClose();
                              action!();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: color,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(actionLabel!,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'إغلاق',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(LucideIcons.x,
                        size: 17, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: TweenAnimationBuilder<double>(
                duration: duration,
                tween: Tween(begin: 1, end: 0),
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 2,
                  color: color,
                  backgroundColor: color.withValues(alpha: .08),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _messageColor(AppMessageType type) => switch (type) {
      AppMessageType.success => AppColors.successGreen,
      AppMessageType.error => AppColors.grillRed,
      AppMessageType.warning => AppColors.ember,
      AppMessageType.info => AppColors.blueMuted,
    };

IconData _messageIcon(AppMessageType type) => switch (type) {
      AppMessageType.success => LucideIcons.circleCheck,
      AppMessageType.error => LucideIcons.circleX,
      AppMessageType.warning => LucideIcons.triangleAlert,
      AppMessageType.info => LucideIcons.info,
    };

Future<void> handleLogout(BuildContext context) async {
  final shouldLogout = await _showLogoutConfirmation(context);
  if (shouldLogout != true || !context.mounted) return;

  _showLoadingDialog(context);
  try {
    await getIt<UserCubit>().logout();
    // UserInitial resets the navigator to LoginScreen and removes this dialog.
    // Popping here can accidentally pop the new login route as well.
  } catch (error) {
    if (!context.mounted) return;
    Navigator.maybePop(context);
    MotionSnackBarError(context, 'فشل تسجيل الخروج: $error');
  }
}

Future<bool?> _showLogoutConfirmation(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.charcoalMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.grillRed.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(LucideIcons.logOut,
              color: AppColors.grillRed, size: 25),
        ),
        title: Text('تسجيل الخروج',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(
          'هل تريد إنهاء الجلسة الحالية والعودة إلى شاشة تسجيل الدخول؟',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('البقاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.grillRed),
            icon: const Icon(LucideIcons.logOut, size: 17),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    ),
  );
}

void _showLoadingDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.charcoalMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Text('جاري تسجيل الخروج...',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    ),
  );
}
