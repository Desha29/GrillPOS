import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/functions/messege.dart';
import '../../../core/security/permission_guard.dart';
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
    final cubit = getIt<UserCubit>();
    if (cubit.allUsers.isEmpty) cubit.getAllUsers();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserCubit>.value(
      value: getIt<UserCubit>(),
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: _UserManagementView(),
      ),
    );
  }
}

class _UserManagementView extends StatefulWidget {
  const _UserManagementView();

  @override
  State<_UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<_UserManagementView> {
  final _searchController = TextEditingController();
  String _query = '';
  UserType? _roleFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<User> _filtered(List<User> users) {
    final query = _query.trim().toLowerCase();
    return users.where((user) {
      if (_roleFilter != null && user.userType != _roleFilter) return false;
      if (query.isEmpty) return true;
      return user.name.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<UserCubit>();
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: BlocListener<UserCubit, UserStates>(
          listener: (context, state) {
            if (state is UserFailure) {
              MotionSnackBarError(context, state.error);
            } else if (state is UserSuccess) {
              MotionSnackBarSuccess(context, state.message);
            }
          },
          child: BlocBuilder<UserCubit, UserStates>(
            builder: (context, state) {
              final users = cubit.allUsers;
              final visibleUsers = _filtered(users);
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScreenHeader(
                      title: 'إدارة فريق العمل',
                      subtitle:
                          'الحسابات والصلاحيات والوصول الآمن إلى GrillPOS',
                      icon: LucideIcons.usersRound,
                      trailingIcon: LucideIcons.userPlus,
                      onTrailingPressed: () => _showUserEditor(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _UserStats(users: users, currentUser: cubit.currentUser),
                    const SizedBox(height: AppSpacing.md),
                    _UserToolbar(
                      controller: _searchController,
                      selectedRole: _roleFilter,
                      onSearchChanged: (value) =>
                          setState(() => _query = value),
                      onRoleChanged: (value) =>
                          setState(() => _roleFilter = value),
                      onRefresh: cubit.getAllUsers,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: Stack(
                        children: [
                          if (users.isEmpty && state is UserLoading)
                            const _UsersLoading()
                          else if (users.isEmpty)
                            _UsersEmpty(
                              filtered: false,
                              onAction: () => _showUserEditor(context),
                            )
                          else if (visibleUsers.isEmpty)
                            _UsersEmpty(
                              filtered: true,
                              onAction: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _roleFilter = null;
                                });
                              },
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 1380
                                    ? 4
                                    : constraints.maxWidth >= 1020
                                        ? 3
                                        : constraints.maxWidth >= 660
                                            ? 2
                                            : 1;
                                return GridView.builder(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSpacing.lg),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: AppSpacing.md,
                                    mainAxisSpacing: AppSpacing.md,
                                    mainAxisExtent: 276,
                                  ),
                                  itemCount: visibleUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = visibleUsers[index];
                                    return _UserCard(
                                      user: user,
                                      isCurrent: user.username ==
                                          cubit.currentUser.username,
                                      onEdit: () => _showUserEditor(
                                        context,
                                        existing: user,
                                      ),
                                      onDelete: () =>
                                          _confirmDelete(context, user),
                                    );
                                  },
                                );
                              },
                            ),
                          if (state is UserLoading && users.isNotEmpty)
                            const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: LinearProgressIndicator(
                                minHeight: 2,
                                color: AppColors.warmOrange,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showUserEditor(
    BuildContext context, {
    User? existing,
  }) async {
    final cubit = context.read<UserCubit>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final usernameController =
        TextEditingController(text: existing?.username ?? '');
    final passwordController = TextEditingController();
    var role = existing?.userType ?? UserType.cashier;
    var selectedPermissions = existing == null
        ? Set<AppPermission>.from(PermissionGuard.defaultCashierPermissions)
        : Set<AppPermission>.from(PermissionGuard.permissionsFor(existing));
    var obscurePassword = true;
    String? validationError;
    final editing = existing != null;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.surfaceColor,
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: AppColors.borderColor),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DialogHeader(
                    icon: editing
                        ? LucideIcons.userRoundPen
                        : LucideIcons.userPlus,
                    title:
                        editing ? 'تعديل حساب المستخدم' : 'إضافة مستخدم جديد',
                    subtitle: editing
                        ? 'حدّث الاسم أو الدور أو كلمة المرور بأمان.'
                        : 'أنشئ حساباً واضح الدور وجاهزاً لتسجيل الدخول.',
                    onClose: () => Navigator.pop(dialogContext),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: nameController,
                    autofocus: !editing,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                      prefixIcon: Icon(LucideIcons.badge),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: usernameController,
                    readOnly: editing,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'اسم المستخدم',
                      hintText: 'username',
                      prefixIcon: const Icon(LucideIcons.atSign),
                      helperText: editing
                          ? 'اسم الدخول ثابت لحماية السجل المالي.'
                          : 'حروف إنجليزية وأرقام و . _ - فقط',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText:
                          editing ? 'كلمة مرور جديدة (اختياري)' : 'كلمة المرور',
                      prefixIcon: const Icon(LucideIcons.lockKeyhole),
                      suffixIcon: IconButton(
                        tooltip: obscurePassword ? 'إظهار' : 'إخفاء',
                        onPressed: () => setDialogState(
                          () => obscurePassword = !obscurePassword,
                        ),
                        icon: Icon(
                          obscurePassword
                              ? LucideIcons.eye
                              : LucideIcons.eyeOff,
                        ),
                      ),
                      helperText: editing
                          ? 'اتركها فارغة للاحتفاظ بكلمة المرور الحالية.'
                          : '6 أحرف على الأقل.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'الدور والصلاحيات',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleChoice(
                          title: 'كاشير',
                          subtitle: 'بيع، طلبات، طاولات وصيانة',
                          icon: LucideIcons.walletCards,
                          color: AppColors.blueMuted,
                          selected: role == UserType.cashier,
                          onTap: () =>
                              setDialogState(() => role = UserType.cashier),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _RoleChoice(
                          title: 'مدير',
                          subtitle: 'وصول كامل وإدارة النظام',
                          icon: LucideIcons.shieldCheck,
                          color: AppColors.warmOrange,
                          selected: role == UserType.manager,
                          onTap: () =>
                              setDialogState(() => role = UserType.manager),
                        ),
                      ),
                    ],
                  ),
                  if (role == UserType.cashier) ...[
                    const SizedBox(height: 16),
                    _PermissionEditor(
                      selected: selectedPermissions,
                      onChanged: (permissions) => setDialogState(
                        () => selectedPermissions = permissions,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    const _ManagerPermissionsNotice(),
                  ],
                  if (validationError != null) ...[
                    const SizedBox(height: 14),
                    _InlineError(message: validationError!),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('إلغاء'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final username = usernameController.text.trim();
                          final password = passwordController.text.trim();
                          final usernamePattern =
                              RegExp(r'^[a-zA-Z0-9_.-]{3,30}$');
                          String? error;
                          if (name.length < 2) {
                            error = 'اكتب اسماً واضحاً من حرفين على الأقل.';
                          } else if (!usernamePattern.hasMatch(username)) {
                            error = 'اسم المستخدم غير صالح.';
                          } else if (!editing && password.length < 6) {
                            error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.';
                          } else if (editing &&
                              password.isNotEmpty &&
                              password.length < 6) {
                            error = 'كلمة المرور الجديدة قصيرة جداً.';
                          }
                          if (error != null) {
                            setDialogState(() => validationError = error);
                            return;
                          }
                          setDialogState(() => validationError = null);
                          final user = User(
                            username: username,
                            password: password,
                            name: name,
                            phone: existing?.phone ?? '',
                            userType: role,
                            permissionKeys: role == UserType.manager
                                ? null
                                : PermissionGuard.keysOf(selectedPermissions),
                          );
                          final saved = editing
                              ? await cubit.updateUser(user)
                              : await cubit.saveUser(user);
                          if (saved && dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.warmOrange,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(
                          editing ? LucideIcons.save : LucideIcons.userPlus,
                          size: 17,
                        ),
                        label:
                            Text(editing ? 'حفظ التعديلات' : 'إضافة المستخدم'),
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

    nameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, User user) async {
    final cubit = context.read<UserCubit>();
    if (user.username == cubit.currentUser.username) {
      MotionSnackBarWarning(context, 'لا يمكنك حذف الحساب المستخدم حالياً.');
      return;
    }
    final managers = cubit.allUsers
        .where((item) => item.userType == UserType.manager)
        .length;
    if (user.userType == UserType.manager && managers <= 1) {
      MotionSnackBarWarning(context, 'يجب الاحتفاظ بحساب مدير واحد على الأقل.');
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.borderColor),
            ),
            icon: const Icon(
              LucideIcons.userRoundX,
              color: AppColors.grillRed,
              size: 34,
            ),
            title: const Text('حذف حساب المستخدم؟'),
            content: Text(
              'سيتم منع @${user.username} من تسجيل الدخول. لن تُحذف السجلات المالية المرتبطة بالحساب.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('عودة'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.grillRed,
                ),
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: const Text('تأكيد الحذف'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await cubit.deleteUser(user.username);
  }
}

class _UserStats extends StatelessWidget {
  const _UserStats({required this.users, required this.currentUser});

  final List<User> users;
  final User currentUser;

  @override
  Widget build(BuildContext context) {
    final managers =
        users.where((user) => user.userType == UserType.manager).length;
    final cashiers = users.length - managers;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final cards = [
          _StatCard(
            label: 'إجمالي الفريق',
            value: '${users.length}',
            icon: LucideIcons.usersRound,
            color: AppColors.blueMuted,
          ),
          _StatCard(
            label: 'المديرون',
            value: '$managers',
            icon: LucideIcons.shieldCheck,
            color: AppColors.warmOrange,
          ),
          _StatCard(
            label: 'الكاشير',
            value: '$cashiers',
            icon: LucideIcons.walletCards,
            color: AppColors.successGreen,
          ),
          _StatCard(
            label: 'الحساب الحالي',
            value: '@${currentUser.username}',
            icon: LucideIcons.userCheck,
            color: const Color(0xFF8B5CF6),
          ),
        ];
        if (compact) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: cards
                  .map((card) => SizedBox(width: 190, child: card))
                  .expand((card) => [card, const SizedBox(width: 10)])
                  .toList(),
            ),
          );
        }
        return Row(
          children: cards
              .map((card) => Expanded(child: card))
              .expand((card) => [card, const SizedBox(width: 10)])
              .toList()
            ..removeLast(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserToolbar extends StatelessWidget {
  const _UserToolbar({
    required this.controller,
    required this.selectedRole,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final UserType? selectedRole;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<UserType?> onRoleChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 680;
          final search = TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو اسم المستخدم...',
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(LucideIcons.x, size: 17),
                    ),
              isDense: true,
            ),
          );
          final filters = Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _FilterChip(
                label: 'الكل',
                selected: selectedRole == null,
                onTap: () => onRoleChanged(null),
              ),
              _FilterChip(
                label: 'مدير',
                selected: selectedRole == UserType.manager,
                onTap: () => onRoleChanged(UserType.manager),
              ),
              _FilterChip(
                label: 'كاشير',
                selected: selectedRole == UserType.cashier,
                onTap: () => onRoleChanged(UserType.cashier),
              ),
              IconButton.outlined(
                tooltip: 'تحديث',
                onPressed: onRefresh,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
              ),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 10), filters],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              filters,
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.warmOrange.withValues(alpha: .15),
      side: BorderSide(
        color: selected ? AppColors.warmOrange : AppColors.borderColor,
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.warmOrange : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  const _UserCard({
    required this.user,
    required this.isCurrent,
    required this.onEdit,
    required this.onDelete,
  });

  final User user;
  final bool isCurrent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final manager = widget.user.userType == UserType.manager;
    final color = manager ? AppColors.warmOrange : AppColors.blueMuted;
    final permissionCount = PermissionGuard.permissionsFor(widget.user).length;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                _hovered ? color.withValues(alpha: .55) : AppColors.borderColor,
            width: _hovered ? 1.4 : 1,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: .10),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: .32)),
                  ),
                  child: Text(
                    widget.user.name.trim().isEmpty
                        ? '?'
                        : widget.user.name.trim()[0].toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@${widget.user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isCurrent)
                  _Pill(
                    label: 'الحالي',
                    color: AppColors.successGreen,
                    icon: LucideIcons.circleCheck,
                  ),
              ],
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                _Pill(
                  label: manager ? 'مدير النظام' : 'كاشير',
                  color: color,
                  icon: manager
                      ? LucideIcons.shieldCheck
                      : LucideIcons.walletCards,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    manager
                        ? 'وصول كامل لكل وحدات النظام'
                        : '$permissionCount صلاحيات تشغيلية',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.charcoalLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    manager ? LucideIcons.settings2 : LucideIcons.shoppingCart,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      manager
                          ? 'الإدارة، التقارير، المخزون والإعدادات'
                          : 'نقطة البيع، الطلبات، الطاولات والمبيعات',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(LucideIcons.userRoundPen, size: 16),
                    label: const Text('تعديل'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: widget.isCurrent ? 'الحساب الحالي' : 'حذف الحساب',
                  onPressed: widget.isCurrent ? null : widget.onDelete,
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.grillRed,
                  ),
                  icon: const Icon(LucideIcons.trash2, size: 17),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionEditor extends StatelessWidget {
  const _PermissionEditor({
    required this.selected,
    required this.onChanged,
  });

  final Set<AppPermission> selected;
  final ValueChanged<Set<AppPermission>> onChanged;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AppPermission>>{};
    for (final permission in AppPermission.values) {
      groups.putIfAbsent(permission.group, () => []).add(permission);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.shieldEllipsis,
                color: AppColors.blueMuted,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'صلاحيات هذا المستخدم',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${selected.length} من ${AppPermission.values.length} صلاحية مفعلة',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'إعداد سريع',
                icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                onSelected: (value) {
                  final permissions = switch (value) {
                    'all' => Set<AppPermission>.from(AppPermission.values),
                    'none' => <AppPermission>{},
                    _ => Set<AppPermission>.from(
                        PermissionGuard.defaultCashierPermissions,
                      ),
                  };
                  onChanged(permissions);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'default',
                      child: Text('صلاحيات الكاشير الافتراضية')),
                  PopupMenuItem(value: 'all', child: Text('تفعيل الكل')),
                  PopupMenuItem(value: 'none', child: Text('إلغاء الكل')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 5),
              child: Text(
                entry.key,
                style: const TextStyle(
                  color: AppColors.warmOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final permission in entry.value)
                  FilterChip(
                    selected: selected.contains(permission),
                    onSelected: (enabled) {
                      final next = Set<AppPermission>.from(selected);
                      enabled ? next.add(permission) : next.remove(permission);
                      onChanged(next);
                    },
                    showCheckmark: true,
                    checkmarkColor: Colors.white,
                    selectedColor: AppColors.blueMuted,
                    label: Text(permission.label),
                    labelStyle: TextStyle(
                      color: selected.contains(permission)
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: selected.contains(permission)
                          ? AppColors.blueMuted
                          : AppColors.borderColor,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ManagerPermissionsNotice extends StatelessWidget {
  const _ManagerPermissionsNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warmOrange.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warmOrange.withValues(alpha: .22),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.shieldCheck,
            color: AppColors.warmOrange,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'حساب المدير يمتلك كل الصلاحيات دائماً لحماية الوصول الإداري.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChoice extends StatelessWidget {
  const _RoleChoice({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: .12) : AppColors.charcoalLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.borderColor,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 7),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.warmOrange.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.warmOrange, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'إغلاق',
          onPressed: onClose,
          icon: const Icon(LucideIcons.x),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.grillRed.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.grillRed.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.circleAlert,
              color: AppColors.grillRed, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.grillRed,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersLoading extends StatelessWidget {
  const _UsersLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.warmOrange),
    );
  }
}

class _UsersEmpty extends StatelessWidget {
  const _UsersEmpty({required this.filtered, required this.onAction});

  final bool filtered;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtered ? LucideIcons.searchX : LucideIcons.usersRound,
            color: AppColors.textSecondary.withValues(alpha: .55),
            size: 54,
          ),
          const SizedBox(height: 14),
          Text(
            filtered ? 'لا توجد حسابات تطابق البحث' : 'لا توجد حسابات بعد',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filtered
                ? 'جرّب مسح البحث أو تغيير فلتر الدور.'
                : 'أضف أول مستخدم وحدد صلاحياته.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: Icon(filtered ? LucideIcons.rotateCcw : LucideIcons.userPlus),
            label: Text(filtered ? 'مسح الفلاتر' : 'إضافة مستخدم'),
          ),
        ],
      ),
    );
  }
}
