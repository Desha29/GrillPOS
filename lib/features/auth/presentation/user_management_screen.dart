import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../data/models/user_model.dart';
import 'cubit/user_cubit.dart';
import 'cubit/user_states.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  @override
  void initState() {
    super.initState();
    final userCubit = getIt<UserCubit>();
    if (userCubit.allUsers.isEmpty) {
      userCubit.getAllUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserCubit>.value(
      value: getIt<UserCubit>(),
      child: const _UserManagementView(),
    );
  }
}

class _UserManagementView extends StatelessWidget {
  const _UserManagementView();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = width > 1400 ? 5 : width > 1100 ? 4 : width > 800 ? 3 : width > 500 ? 2 : 1;

    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'إدارة الفريق',
                subtitle: 'إدارة صلاحيات المدير والكاشير',
                icon: LucideIcons.users,
                trailingIcon: Icons.person_add,
                onTrailingPressed: () => _showAddUserDialog(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: BlocBuilder<UserCubit, UserStates>(
                  builder: (context, state) {
                    if (state is UserLoading) {
                      return Center(
                          child: CircularProgressIndicator(
                              color: AppColors.warmOrange));
                    }

                    final users = getIt<UserCubit>().allUsers;
                    if (users.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.users,
                                size: 64,
                                color: AppColors.mutedColor.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'لا يوجد مستخدمين',
                              style: TextStyle(
                                  color: AppColors.creamMuted, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: columns > 3 ? 0.82 : 1.1,
                      ),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        return _AnimatedUserCard(
                          user: users[index],
                          index: index,
                          columns: columns,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = 'cashier';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: AppColors.charcoalMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            side: BorderSide(color: AppColors.borderColor, width: 1.5),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إضافة مستخدم جديد',
                        style: TextStyle(
                            color: AppColors.cream,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: AppColors.creamMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: AppColors.cream),
                    decoration: InputDecoration(
                      labelText: 'الاسم كامل',
                      prefixIcon:
                          Icon(Icons.badge, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: usernameCtrl,
                    style: TextStyle(color: AppColors.cream),
                    decoration: InputDecoration(
                      labelText: 'اسم المستخدم للدخول',
                      prefixIcon:
                          Icon(Icons.person, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    style: TextStyle(color: AppColors.cream),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon:
                          Icon(Icons.lock, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    dropdownColor: AppColors.charcoalLight,
                    style: TextStyle(color: AppColors.cream, fontSize: 16),
                    icon: Icon(Icons.arrow_drop_down, color: AppColors.cream),
                    items: const [
                      DropdownMenuItem(
                          value: 'manager', child: Text('مدير النظام')),
                      DropdownMenuItem(
                          value: 'cashier', child: Text('كاشير مبيعات')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => selectedRole = v);
                    },
                    decoration: InputDecoration(
                      labelText: 'نوع الصلاحية',
                      prefixIcon: Icon(Icons.admin_panel_settings,
                          color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.creamMuted,
                        ),
                        child: const Text('إلغاء'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton.icon(
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          final username = usernameCtrl.text.trim();
                          final password = passwordCtrl.text.trim();
                          if (name.isEmpty ||
                              username.isEmpty ||
                              password.isEmpty) return;
                          getIt<UserCubit>().saveUser(
                            User(
                              username: username,
                              password: password,
                              name: name,
                              phone: '',
                              userType: selectedRole == 'manager'
                                  ? UserType.manager
                                  : UserType.cashier,
                            ),
                          );
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('إضافة المستخدم'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warmOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
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

class _AnimatedUserCard extends StatefulWidget {
  final User user;
  final int index;
  final int columns;

  const _AnimatedUserCard({required this.user, required this.index, required this.columns});

  @override
  State<_AnimatedUserCard> createState() => _AnimatedUserCardState();
}

class _AnimatedUserCardState extends State<_AnimatedUserCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.9, curve: Curves.easeOut),
      ),
    );

    // Stagger the animation based on index
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(
                    color: _isHovered
                        ? accentColor.withOpacity(0.5)
                        : AppColors.borderColor,
                    width: _isHovered ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? accentColor.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: _isHovered ? 16 : 4,
                      offset: Offset(0, _isHovered ? 6 : 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.columns > 3 ? AppSpacing.md : AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar
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
                                    AppColors.warmOrange
                                        .withOpacity(0.25),
                                    AppColors.ember
                                        .withOpacity(0.15),
                                  ]
                                : [
                                    AppColors.charcoalLight
                                        .withOpacity(0.6),
                                    AppColors.charcoalMedium,
                                  ],
                          ),
                          border: Border.all(
                            color: isManager
                                ? AppColors.warmOrange
                                    .withOpacity(0.5)
                                : AppColors.borderColor,
                            width: 2.5,
                          ),
                          boxShadow: [
                            if (_isHovered)
                              BoxShadow(
                                color:
                                    accentColor.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.user.name.isNotEmpty
                                ? widget.user.name[0]
                                    .toUpperCase()
                                : '?',
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
                      const SizedBox(height: 14),

                      // Name
                      Text(
                        widget.user.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cream,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Username
                      Text(
                        '@${widget.user.username}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isManager
                                ? [
                                    AppColors.warmOrange
                                        .withOpacity(0.2),
                                    AppColors.ember
                                        .withOpacity(0.1),
                                  ]
                                : [
                                    AppColors.charcoalLight
                                        .withOpacity(0.4),
                                    AppColors.charcoalLight
                                        .withOpacity(0.2),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isManager
                                ? AppColors.warmOrange
                                    .withOpacity(0.3)
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
                              size: 14,
                              color: isManager
                                  ? AppColors.warmOrange
                                  : AppColors.creamMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isManager ? 'مدير' : 'كاشير',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isManager
                                    ? AppColors.warmOrange
                                    : AppColors.creamMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Actions
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          _ActionButton(
                            icon: LucideIcons.edit3,
                            color: AppColors.ember,
                            tooltip: 'تعديل',
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: LucideIcons.trash2,
                            color: AppColors.grillRed,
                            tooltip: 'حذف',
                            onTap: () {
                              getIt<UserCubit>()
                                  .deleteUser(widget.user.username);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.color.withOpacity(0.15)
                  : AppColors.charcoalLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isHovered
                    ? widget.color.withOpacity(0.3)
                    : Colors.transparent,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: _isHovered ? widget.color : AppColors.mutedColor,
            ),
          ),
        ),
      ),
    );
  }
}
