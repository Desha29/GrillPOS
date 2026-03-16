import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../data/models/user_model.dart';
import 'cubit/user_cubit.dart';
import 'cubit/user_states.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserCubit>.value(
      value: getIt<UserCubit>()..getAllUsers(),
      child: const _UserManagementView(),
    );
  }
}

class _UserManagementView extends StatelessWidget {
  const _UserManagementView();

  @override
  Widget build(BuildContext context) {
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
                icon: Icons.people_outline,
                trailingIcon: Icons.person_add,
                onTrailingPressed: () => _showAddUserDialog(context),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: BlocBuilder<UserCubit, UserStates>(
                  builder: (context, state) {
                    if (state is UserLoading) {
                      return Center(child: CircularProgressIndicator(color: AppColors.warmOrange));
                    }

                    final users = getIt<UserCubit>().allUsers;
                    if (users.isEmpty) {
                      return Center(
                        child: Text(
                          'لا يوجد مستخدمين',
                          style: TextStyle(color: AppColors.creamMuted),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _UserTile(user: user);
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
                      prefixIcon: Icon(Icons.badge, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: usernameCtrl,
                    style: TextStyle(color: AppColors.cream),
                    decoration: InputDecoration(
                      labelText: 'اسم المستخدم للدخول',
                      prefixIcon: Icon(Icons.person, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    style: TextStyle(color: AppColors.cream),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: Icon(Icons.lock, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    dropdownColor: AppColors.charcoalLight,
                    style: TextStyle(color: AppColors.cream, fontSize: 16),
                    icon: Icon(Icons.arrow_drop_down, color: AppColors.cream),
                    items: const [
                      DropdownMenuItem(value: 'manager', child: Text('مدير النظام')),
                      DropdownMenuItem(value: 'cashier', child: Text('كاشير مبيعات')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => selectedRole = v);
                    },
                    decoration: InputDecoration(
                      labelText: 'نوع الصلاحية',
                      prefixIcon: Icon(Icons.admin_panel_settings, color: AppColors.mutedColor),
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
                          if (name.isEmpty || username.isEmpty || password.isEmpty) return;
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
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

class _UserTile extends StatelessWidget {
  final User user;

  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final isManager = user.userType == UserType.manager;

    return Card(
      color: AppColors.surfaceDark,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: AppColors.borderColor),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isManager
                ? AppColors.warmOrange.withOpacity(0.15)
                : AppColors.charcoalLight,
          ),
          child: Center(
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isManager ? AppColors.warmOrange : AppColors.cream,
              ),
            ),
          ),
        ),
        title: Text(user.name,
            style: TextStyle(
                color: AppColors.cream, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${user.username} • ${isManager ? "مدير" : "كاشير"}',
          style: TextStyle(color: AppColors.creamMuted, fontSize: 13),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isManager
                ? AppColors.warmOrange.withOpacity(0.15)
                : AppColors.charcoalLight.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isManager ? 'مدير' : 'كاشير',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isManager ? AppColors.warmOrange : AppColors.creamMuted,
            ),
          ),
        ),
      ),
    );
  }
}
