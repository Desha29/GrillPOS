// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:grill_pos/core/constants/app_colors.dart';
import 'package:grill_pos/core/constants/app_spacing.dart';
import 'package:grill_pos/core/di/dependency_injection.dart';
import 'package:grill_pos/core/functions/messege.dart';
import 'package:grill_pos/features/auth/data/models/user_model.dart';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/components/logo.dart';
import '../../../core/data/services/persistence_initializer.dart';

import '../../dashboard/presentation/dashboard_screen.dart';

import '../../settings/presentation/cubit/settings_cubit.dart';
import 'cubit/user_cubit.dart';
import 'cubit/user_states.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    getIt<UserCubit>().getAllUsers();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (!PersistenceInitializer.isEnabled) {
        final success = await PersistenceInitializer.promptForDataPath(
          context,
          allowCancel: false,
        );
        if (success && mounted) {
          getIt<UserCubit>().getAllUsers();
          setState(() {});
        }
      } else {
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 3;
    double childAspectRatio = 1.1;

    if (screenWidth < 900) {
      crossAxisCount = 2;
      childAspectRatio = 1.0;
    }
    if (screenWidth < 600) {
      crossAxisCount = 1;
      childAspectRatio = 1.1;
    }

    return BlocProvider<UserCubit>.value(
      value: getIt<UserCubit>(),
      child: BlocListener<UserCubit, UserStates>(
        listener: (context, state) {
          if (state is UserFailure) {
            MotionSnackBarError(context, state.error);
          } else if (state is LoginSuccess) {
            if (state.isExistingSession) {
              MotionSnackBarInfo(context, state.message);
            } else {
              MotionSnackBarSuccess(context, state.message);
            }
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ));
          } else if (state is UserSuccess) {
            MotionSnackBarSuccess(context, state.message);
            if (state.message == "تم تسجيل الدخول بنجاح") {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardScreen(),
                  ));
            } else {
              MotionSnackBarInfo(context, state.message);
            }
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.charcoalDark,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.charcoalDark,
                  AppColors.charcoalMedium,
                  AppColors.charcoalDark,
                ],
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    const Logo(isMobile: false, avatarRadius: 90),
                    const SizedBox(height: 24),

                    Text(
                      'اختر المستخدم لتسجيل الدخول',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.cream,
                              ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: BlocBuilder<UserCubit, UserStates>(
                        builder: (context, state) {
                          if (state is UserLoading) {
                            return const Center(
                                child: CircularProgressIndicator());
                          } else if (state is UsersLoaded) {
                            if (state.users.isEmpty) {
                              return Center(
                                  child: Text(
                                "لا يوجد مستخدمين. يرجى إضافة مستخدم أولاً.",
                                style:
                                    TextStyle(color: AppColors.creamMuted),
                              ));
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.all(20),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: childAspectRatio,
                              ),
                              itemCount: state.users.length,
                              itemBuilder: (context, index) {
                                final user = state.users[index];
                                return _LoginUserCard(
                                  user: user,
                                  index: index,
                                  onTap: () => _showPasswordDialog(context, user),
                                );
                              },
                            );
                          } else if (state is UserFailure) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(state.error,
                                      style: TextStyle(
                                          color: AppColors.grillRed)),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: () {
                                      UserCubit.get(context).getAllUsers();
                                    },
                                    child: const Text("إعادة المحاولة"),
                                  )
                                ],
                              ),
                            );
                          }
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '© 2026 GrillPOS. جميع الحقوق محفوظة.',
                      style: TextStyle(color: AppColors.mutedColor),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPasswordDialog(BuildContext context, User user) {
    final passwordController = TextEditingController();
    bool isPasswordVisible = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.charcoalMedium,
                borderRadius:
                    BorderRadius.circular(AppSpacing.dialogRadius),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warmOrange.withOpacity(0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                    color: AppColors.borderColor, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Elegant Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.warmOrange.withOpacity(0.2),
                          AppColors.charcoalLight.withOpacity(0.3),
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.warmOrange.withOpacity(0.4),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warmOrange.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : "?",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.warmOrange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Greetings
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warmOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "مرحباً بك مجدداً",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warmOrange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.cream,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Input Field
                  TextField(
                    controller: passwordController,
                    obscureText: !isPasswordVisible,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: AppColors.cream,
                    ),
                    decoration: InputDecoration(
                      hintText: "••••••••",
                      hintStyle: TextStyle(
                        fontSize: 18,
                        letterSpacing: 3,
                        color: AppColors.mutedColor.withOpacity(0.4),
                      ),
                      filled: true,
                      fillColor: AppColors.charcoalDark,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Icon(LucideIcons.keyRound,
                            color: AppColors.warmOrange, size: 22),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordVisible
                              ? LucideIcons.eye
                              : LucideIcons.eyeOff,
                          color: AppColors.mutedColor,
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            isPasswordVisible = !isPasswordVisible;
                          });
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                        borderSide: BorderSide(
                            color: AppColors.borderColor, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                        borderSide: BorderSide(
                            color: AppColors.warmOrange, width: 2),
                      ),
                    ),
                    onSubmitted: (_) {
                      Navigator.pop(dialogContext);
                      _attemptLogin(
                          context, user.username, passwordController.text);
                    },
                  ),
                  const SizedBox(height: 40),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 18),
                            side: BorderSide(
                                color: AppColors.borderColor, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.buttonRadius),
                            ),
                          ),
                          child: Text(
                            "إلغاء",
                            style: TextStyle(
                              color: AppColors.mutedColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _attemptLogin(context, user.username,
                                passwordController.text);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warmOrange,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 18),
                            elevation: 4,
                            shadowColor:
                                AppColors.warmOrange.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.buttonRadius),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "دخول",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(LucideIcons.logIn, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _attemptLogin(BuildContext context, String username, String password) {
    if (password.isEmpty) {
      MotionSnackBarError(context, "الرجاء إدخال كلمة المرور");
      return;
    }
    getIt<UserCubit>().login(username, password);
  }
}

// ─── Animated Login User Card ──────────────────────────────────────────────
class _LoginUserCard extends StatefulWidget {
  final User user;
  final int index;
  final VoidCallback onTap;

  const _LoginUserCard({
    required this.user,
    required this.index,
    required this.onTap,
  });

  @override
  State<_LoginUserCard> createState() => _LoginUserCardState();
}

class _LoginUserCardState extends State<_LoginUserCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.index * 120), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isManager = widget.user.userType == UserType.manager;
    final accentColor = isManager ? AppColors.warmOrange : AppColors.ember;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: _isHovered
                    ? accentColor.withOpacity(0.5)
                    : AppColors.borderColor,
                width: _isHovered ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? accentColor.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: _isHovered ? 16 : 4,
                  offset: Offset(0, _isHovered ? 6 : 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              hoverColor: Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isHovered ? 64 : 56,
                    height: _isHovered ? 64 : 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isManager
                            ? [
                                AppColors.warmOrange.withOpacity(0.25),
                                AppColors.ember.withOpacity(0.15),
                              ]
                            : [
                                AppColors.charcoalLight.withOpacity(0.5),
                                AppColors.charcoalMedium,
                              ],
                      ),
                      border: Border.all(
                        color: isManager
                            ? AppColors.warmOrange.withOpacity(0.5)
                            : AppColors.borderColor,
                        width: 2.5,
                      ),
                      boxShadow: [
                        if (_isHovered)
                          BoxShadow(
                            color: accentColor.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.user.name.isNotEmpty
                            ? widget.user.name[0].toUpperCase()
                            : "?",
                        style: TextStyle(
                          fontSize: _isHovered ? 26 : 22,
                          fontWeight: FontWeight.w900,
                          color: isManager
                              ? AppColors.warmOrange
                              : AppColors.cream,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.user.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cream,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isManager
                            ? [
                                AppColors.warmOrange.withOpacity(0.2),
                                AppColors.ember.withOpacity(0.1),
                              ]
                            : [
                                AppColors.charcoalLight.withOpacity(0.4),
                                AppColors.charcoalLight.withOpacity(0.2),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isManager
                            ? AppColors.warmOrange.withOpacity(0.3)
                            : AppColors.borderColor,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isManager
                              ? LucideIcons.shieldCheck
                              : LucideIcons.user,
                          size: 12,
                          color: isManager
                              ? AppColors.warmOrange
                              : AppColors.creamMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isManager ? "مدير" : "كاشير",
                          style: TextStyle(
                            color: isManager
                                ? AppColors.warmOrange
                                : AppColors.creamMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
