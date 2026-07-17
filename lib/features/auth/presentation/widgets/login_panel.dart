import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/user_model.dart';
import 'quick_user_selector.dart';
import 'login_text_field.dart';
import 'status_footer.dart';

class LoginPanel extends StatelessWidget {
  const LoginPanel({
    super.key,
    required this.formKey,
    required this.employeeController,
    required this.passwordController,
    required this.passwordFocusNode,
    required this.users,
    required this.selectedUser,
    required this.usersError,
    required this.loadingUsers,
    required this.authenticating,
    required this.passwordVisible,
    required this.onEmployeeChanged,
    required this.onTogglePassword,
    required this.onUserSelected,
    required this.onRetry,
    required this.onSubmit,
    this.loginError,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController employeeController;
  final TextEditingController passwordController;
  final FocusNode passwordFocusNode;
  final List<User> users;
  final User? selectedUser;
  final String? usersError;
  final bool loadingUsers;
  final bool authenticating;
  final bool passwordVisible;
  final ValueChanged<String> onEmployeeChanged;
  final VoidCallback onTogglePassword;
  final ValueChanged<User> onUserSelected;
  final VoidCallback onRetry;
  final VoidCallback onSubmit;
  final String? loginError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(isDark ? 0.45 : 0.75),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Form(
                key: formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brand logo
                      _BrandLogo(),
                      const SizedBox(height: 32),
                      // Welcome text
                      Text(
                        'Welcome Back',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to your Grill POS account',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Error banner
                      if (loginError != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: AppColors.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.errorColor.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            loginError!,
                            style: const TextStyle(
                              color: AppColors.errorColor,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ).animate().shake(),
                      // Quick user selector
                      _SectionLabel(),
                      const SizedBox(height: 12),
                      QuickUserSelector(
                        users: users,
                        selectedUser: selectedUser,
                        loading: loadingUsers,
                        error: usersError,
                        onSelected: onUserSelected,
                        onRetry: onRetry,
                      ),
                      const SizedBox(height: 20),
                      const _CredentialsDivider(),
                      const SizedBox(height: 20),
                      // Employee field
                      LoginTextField(
                        controller: employeeController,
                        label: 'Employee PIN / ID',
                        icon: Icons.badge_outlined,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        onChanged: onEmployeeChanged,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter your employee PIN or ID.'
                                : null,
                      ),
                      const SizedBox(height: 20),
                      // Password field
                      LoginTextField(
                        controller: passwordController,
                        focusNode: passwordFocusNode,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: !passwordVisible,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        suffixIcon: IconButton(
                          tooltip:
                              passwordVisible ? 'Hide password' : 'Show password',
                          onPressed: onTogglePassword,
                          icon: Icon(
                            passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                        onFieldSubmitted: (_) => onSubmit(),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your password.'
                            : null,
                      ),
                      const SizedBox(height: 32),
                      // Sign-in button
                      _SignInButton(
                        loading: authenticating,
                        onPressed: onSubmit,
                      ),
                      const SizedBox(height: 28),
                      const StatusFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
            .animate()
            .slideY(begin: 0.1, duration: 600.ms)
            .fadeIn(),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/grillpos/logo_icon.png',
          height: 44,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.local_fire_department_rounded,
            size: 44,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Grill POS',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.bolt_rounded,
          color: theme.colorScheme.primary,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          'QUICK USER SELECTION',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _CredentialsDivider extends StatelessWidget {
  const _CredentialsDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outlineVariant.withOpacity(0.4);

    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR ENTER CREDENTIALS MANUALLY',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(child: Divider(color: dividerColor)),
      ],
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: theme.colorScheme.onPrimary,
          disabledBackgroundColor: primary.withOpacity(0.55),
          disabledForegroundColor: theme.colorScheme.onPrimary,
          elevation: 0,
          shadowColor: primary.withOpacity(0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: loading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.onPrimary,
                    strokeWidth: 2.4,
                  ),
                )
              : const Text(
                  'SIGN IN',
                  key: ValueKey('label'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ),
    );
  }
}
