import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/services/persistence_initializer.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../data/models/user_model.dart';
import 'cubit/user_cubit.dart';
import 'cubit/user_states.dart';
import 'widgets/hero_panel.dart';
import 'widgets/login_panel.dart';

/// Responsive GrillPOS sign-in UI.
///
/// Loading and authentication are delegated to [UserCubit]; this screen owns
/// presentation-only state.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  late final UserCubit _userCubit;
  late final StreamSubscription<UserStates> _subscription;

  List<User> _users = const [];
  User? _selectedUser;
  String? _usersError;
  String? _loginError;
  bool _loadingUsers = true;
  bool _authenticating = false;
  bool _passwordVisible = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _userCubit = getIt<UserCubit>();
    _subscription = _userCubit.stream.listen(_onUserState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  @override
  void dispose() {
    _subscription.cancel();
    _employeeController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (!mounted) return;
    if (!PersistenceInitializer.isEnabled) {
      final ready = await PersistenceInitializer.promptForDataPath(
        context,
        allowCancel: false,
      );
      if (!mounted) return;
      if (!ready) {
        setState(() {
          _loadingUsers = false;
          _usersError = 'The local data folder could not be configured.';
        });
        return;
      }
    }
    _loadUsers();
  }

  void _loadUsers() {
    if (!mounted) return;
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    _userCubit.getAllUsers();
  }

  void _onUserState(UserStates state) {
    if (!mounted) return;
    if (state is UserLoading) {
      if (!_authenticating) setState(() => _loadingUsers = true);
      return;
    }
    if (state is UsersLoaded) {
      final users = state.users.whereType<User>().toList(growable: false);
      setState(() {
        _users = users;
        _loadingUsers = false;
        _usersError = null;
        _syncSelection(users);
      });
      return;
    }
    if (state is UserFailure) {
      final loginFailure = _authenticating;
      setState(() {
        _authenticating = false;
        _loadingUsers = false;
        if (loginFailure) {
          _loginError = state.error;
        } else {
          _usersError = state.error;
        }
      });
      return;
    }
    if ((state is LoginSuccess || state is UserSuccess) && _authenticating) {
      setState(() => _authenticating = false);
      _openDashboard();
    }
  }

  void _syncSelection(List<User> users) {
    if (users.isEmpty) {
      _selectedUser = null;
      return;
    }
    User? next;
    for (final user in users) {
      if (user.username == _selectedUser?.username) {
        next = user;
        break;
      }
    }
    next ??= users.first;
    _selectedUser = next;
    if (_employeeController.text.trim().isEmpty) {
      _setEmployee(next.username);
    }
  }

  void _selectUser(User user) {
    setState(() {
      _selectedUser = user;
      _setEmployee(user.username);
      _passwordController.clear();
      _loginError = null;
    });
    _passwordFocusNode.requestFocus();
  }

  void _employeeChanged(String value) {
    User? match;
    for (final user in _users) {
      if (user.username.toLowerCase() == value.trim().toLowerCase()) {
        match = user;
        break;
      }
    }
    if (match != _selectedUser) {
      setState(() {
        _selectedUser = match;
        _loginError = null;
      });
    }
  }

  void _setEmployee(String value) {
    _employeeController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_authenticating || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _authenticating = true;
      _loginError = null;
    });
    _userCubit.login(
      _employeeController.text.trim(),
      _passwordController.text,
    );
  }

  void _openDashboard() {
    if (!mounted || _navigating) return;
    _navigating = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;



    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D0E12) : const Color(0xFFF0F1F5),
            image: DecorationImage(
              image: const AssetImage('assets/images/grillpos/login_bg.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(isDark ? 0.6 : 0.25),
                BlendMode.srcOver,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Subtle food & drink icon watermark
              Positioned.fill(
                child: CustomPaint(
                  painter: FoodPatternPainter(
                    color: theme.colorScheme.onSurface
                        .withOpacity(isDark ? 0.012 : 0.022),
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 960;
                  return Row(
                    children: [
                      if (desktop)
                        const Expanded(
                          child: HeroPanel(),
                        ),
                      Expanded(
                        child: LoginPanel(
                          formKey: _formKey,
                          employeeController: _employeeController,
                          passwordController: _passwordController,
                          passwordFocusNode: _passwordFocusNode,
                          users: _users,
                          selectedUser: _selectedUser,
                          usersError: _usersError,
                          loadingUsers: _loadingUsers,
                          authenticating: _authenticating,
                          passwordVisible: _passwordVisible,
                          loginError: _loginError,
                          onEmployeeChanged: _employeeChanged,
                          onTogglePassword: () => setState(
                            () => _passwordVisible = !_passwordVisible,
                          ),
                          onUserSelected: _selectUser,
                          onRetry: _prepare,
                          onSubmit: _submit,
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Floating Theme Switcher Button in Corner
              Positioned(
                top: 16 + MediaQuery.of(context).padding.top,
                right: 24,
                child: SafeArea(
                  child: BlocBuilder<ThemeCubit, ThemeState>(
                    builder: (context, themeState) {
                      return Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(isDark ? 0.2 : 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withOpacity(0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => context.read<ThemeCubit>().toggleTheme(),
                          icon: Icon(
                            themeState.isDarkMode
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: theme.colorScheme.onSurface,
                          ),
                          tooltip: 'Toggle Theme',
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FoodPatternPainter extends CustomPainter {
  final Color color;

  FoodPatternPainter({required this.color});

  static const List<IconData> _foodIcons = [
    Icons.lunch_dining_rounded,
    Icons.local_drink_rounded,
    Icons.local_pizza_rounded,
    Icons.local_fire_department_rounded,
    Icons.coffee_rounded,
    Icons.restaurant_rounded,
    Icons.icecream_rounded,
    Icons.cake_rounded,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: color,
      fontSize: 32,
      fontFamily: 'MaterialIcons',
    );

    const double stepX = 120.0;
    const double stepY = 120.0;
    int index = 0;

    for (double y = 40; y < size.height; y += stepY) {
      // Offset alternate rows for a staggered brick-like pattern
      final double startX = (index % 2 == 0) ? 40.0 : 100.0;
      for (double x = startX; x < size.width; x += stepX) {
        final icon =
            _foodIcons[(index + (x / stepX).round()) % _foodIcons.length];

        final textPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: textStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height / 2),
        );
      }
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
