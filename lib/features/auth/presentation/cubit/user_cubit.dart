import 'package:grill_pos/features/auth/data/models/user_model.dart';
import 'package:grill_pos/features/auth/domain/repository/user_repository_int.dart';
import 'package:grill_pos/features/auth/presentation/cubit/user_states.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/dependency_injection.dart';

import '../../../../core/services/activity_logger.dart';
import '../../../../core/data/models/activity_log.dart';

import '../../../../core/data/services/checkpoint_service.dart';
import '../../../../core/data/services/persistence_initializer.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/security/password_hasher.dart';
import '../../../../core/security/permission_guard.dart';

class UserCubit extends Cubit<UserStates> {
  UserCubit({
    required this.userRepository,
  }) : super(UserInitial());

  final UserRepositoryInt userRepository;

  static UserCubit get(context) => BlocProvider.of(context);
  late User currentUser;
  final bool _isPasswordVisible = false;

  bool get isPasswordVisible => _isPasswordVisible;

  List<User> _users = [];
  List<User> get allUsers => _users;
  List<User> get users =>
      _users; // Access cached users even if state is not Loaded

  Future<void> getAllUsers() async {
    emit(UserLoading());
    final result = await userRepository.getAllUsers();
    result.fold(
      (failure) => emit(UserFailure(failure.message)),
      (usersList) async {
        if (usersList.isEmpty) {
          print('ℹ️ No users found. Seeding default admin...');
          final defaultAdmin = User(
            username: 'admin',
            password: 'admin',
            name: 'مدير النظام',
            userType: UserType.manager,
            phone: '000',
            permissionKeys: null,
          );
          await userRepository.saveUser(defaultAdmin);
          await getAllUsers();
          return;
        }

        // Sort: Managers first
        usersList.sort((a, b) {
          if (a.userType == UserType.manager &&
              b.userType != UserType.manager) {
            return -1;
          }
          if (a.userType != UserType.manager &&
              b.userType == UserType.manager) {
            return 1;
          }
          return 0;
        });
        _users = usersList;
        emit(UsersLoaded(usersList));
      },
    );
  }

  Future<bool> deleteUser(String username) async {
    try {
      PermissionGuard.require(currentUser, AppPermission.manageUsers);
    } on PermissionDeniedException catch (error) {
      emit(UserFailure(error.message));
      return false;
    }
    if (username == currentUser.username) {
      emit(UserFailure('لا يمكنك حذف الحساب المستخدم حالياً.'));
      return false;
    }
    final target =
        _users.where((user) => user.username == username).firstOrNull;
    if (target == null) {
      emit(UserFailure('المستخدم المطلوب غير موجود.'));
      return false;
    }
    final managers = _users.where((user) => user.userType == UserType.manager);
    if (target.userType == UserType.manager && managers.length <= 1) {
      emit(UserFailure('يجب الاحتفاظ بحساب مدير واحد على الأقل.'));
      return false;
    }

    emit(UserLoading());
    final result = await userRepository.deleteUser(username);
    return result.fold(
      (failure) async {
        emit(UserFailure(failure.message));
        return false;
      },
      (_) async {
        emit(UserSuccess("تم حذف المستخدم بنجاح"));

        try {
          await getIt<ActivityLogger>().logActivity(
            type: ActivityType.userDelete,
            description: 'حذف مستخدم: $username',
            userName: currentUser.name,
          );
        } catch (_) {}

        await getAllUsers();
        return true;
      },
    );
  }

  Future<bool> saveUser(User user) async {
    try {
      PermissionGuard.require(currentUser, AppPermission.manageUsers);
    } on PermissionDeniedException catch (error) {
      emit(UserFailure(error.message));
      return false;
    }
    if (_users.any((existing) => existing.username == user.username)) {
      emit(UserFailure('اسم المستخدم مستخدم بالفعل.'));
      return false;
    }

    emit(UserLoading());
    final result = await userRepository.saveUser(user);
    return result.fold(
      (failure) async {
        emit(UserFailure(failure.message));
        return false;
      },
      (_) async {
        emit(UserSuccess("تم إضافة المستخدم بنجاح"));
        try {
          await getIt<ActivityLogger>().logActivity(
            type: ActivityType.userAdd,
            description: 'إضافة مستخدم: ${user.name}',
            userName: currentUser.name,
          );
        } catch (_) {}

        await getAllUsers();
        return true;
      },
    );
  }

  Future<bool> updateUser(User user) async {
    try {
      PermissionGuard.require(currentUser, AppPermission.manageUsers);
    } on PermissionDeniedException catch (error) {
      emit(UserFailure(error.message));
      return false;
    }
    final existing =
        _users.where((item) => item.username == user.username).firstOrNull;
    if (existing == null) {
      emit(UserFailure('المستخدم المطلوب غير موجود.'));
      return false;
    }
    if (existing.username == currentUser.username &&
        user.userType != currentUser.userType) {
      emit(UserFailure('لا يمكنك تغيير صلاحية الحساب المستخدم حالياً.'));
      return false;
    }
    final managerCount =
        _users.where((item) => item.userType == UserType.manager).length;
    if (existing.userType == UserType.manager &&
        user.userType != UserType.manager &&
        managerCount <= 1) {
      emit(UserFailure('يجب الاحتفاظ بحساب مدير واحد على الأقل.'));
      return false;
    }

    emit(UserLoading());
    final result = await userRepository.updateUser(user);
    return result.fold(
      (failure) async {
        emit(UserFailure(failure.message));
        return false;
      },
      (_) async {
        if (currentUser.username == user.username) {
          currentUser = user;
        }
        emit(UserSuccess("تم تحديث المستخدم بنجاح"));

        try {
          await getIt<ActivityLogger>().logActivity(
            type: ActivityType.userUpdate,
            description: 'تحديث مستخدم: ${user.name}',
            userName: currentUser.name,
          );
        } catch (_) {}

        await getAllUsers();
        return true;
      },
    );
  }

  void getUser(String username) async {
    emit(UserLoading());
    final result = await userRepository.getUser(username);
    result.fold(
      (failure) => emit(UserFailure(failure.message)),
      (user) =>
          emit(UserSuccess("User fetched successfully: ${user.username}")),
    );
  }

  void login(String username, String password) async {
    emit(UserLoading());
    final trimmedUsername = username.trim();
    final trimmedPassword = password.trim();

    final result = await userRepository.getUser(trimmedUsername);
    result.fold(
      (failure) => emit(UserFailure(failure.message)),
      (user) async {
        if (PasswordHasher.verify(trimmedPassword, user.password)) {
          final usesLegacyPassword = !PasswordHasher.isEncoded(user.password);
          currentUser = User(
            username: user.username,
            name: user.name,
            phone: user.phone,
            userType: user.userType,
            password: '',
            permissionKeys: user.permissionKeys == null
                ? null
                : Set<String>.from(user.permissionKeys!),
          );
          if (usesLegacyPassword) {
            await userRepository.updateUser(User(
              username: user.username,
              name: user.name,
              phone: user.phone,
              userType: user.userType,
              password: trimmedPassword,
              permissionKeys: user.permissionKeys == null
                  ? null
                  : Set<String>.from(user.permissionKeys!),
            ));
          }
          try {
            // Log activity
            await getIt<ActivityLogger>().logActivity(
              type: ActivityType.login,
              description: 'تسجيل دخول',
              userName: user.name,
            );

            // Create checkpoint on login
            await CheckpointService().createCheckpoint(
                reason: 'login_${user.username}', userName: user.name);

            await _checkAndOpenSession();

            emit(UserSuccess("تم تسجيل الدخول بنجاح"));
          } catch (e, stack) {
            print(e);
            print(stack);
            emit(UserFailure("فشل فتح اليوم: $e"));
          }
        } else {
          emit(UserFailure("كلمة المرور غير صحيحة"));
        }
      },
    );
  }

  Future<void> _checkAndOpenSession() async {
    try {
      final db = PersistenceInitializer.persistenceManager!.sqliteManager;
      final res = await db.query('shifts', where: 'is_open = 1', limit: 1);
      if (res.isEmpty) {
        final shiftId = const Uuid().v4();
        await db.insert('shifts', {
          'id': shiftId,
          'user_id': currentUser.username,
          'open_time': DateTime.now().toIso8601String(),
          'is_open': 1,
        });
        await getIt<ActivityLogger>().logActivity(
          type: ActivityType.sessionOpen,
          description: 'بداية يوم عمل جديد',
          userName: currentUser.name,
          sessionId: shiftId,
        );
      }
    } catch (e) {
      print('Failed to open session: $e');
    }
  }

  void closeSession() async {
    try {
      PermissionGuard.checkDayClosePermission(currentUser);
    } on PermissionDeniedException catch (error) {
      emit(UserFailure(error.message));
      return;
    }
    emit(CloseSessionLoading());
    try {
      final db = PersistenceInitializer.persistenceManager!.sqliteManager;
      final res = await db.query('shifts', where: 'is_open = 1', limit: 1);
      if (res.isNotEmpty) {
        final shiftId = res.first['id'] as String;
        await db.update(
            'shifts',
            {
              'is_open': 0,
              'close_time': DateTime.now().toIso8601String(),
              'closed_by': currentUser.username,
            },
            where: 'id = ?',
            whereArgs: [shiftId]);

        await getIt<ActivityLogger>().logActivity(
          type: ActivityType.sessionClose,
          description: 'إنهاء وتصفيّة يوم العمل',
          userName: currentUser.name,
          sessionId: shiftId,
        );

        await db.insert('daily_reports', {
          'id': const Uuid().v4(),
          'report_date': DateTime.now().toIso8601String(),
          'shift_id': shiftId,
          'created_by': currentUser.username,
          'restaurant_id': 'default',
          'created_at': DateTime.now().toIso8601String(),
        });
        emit(UserSuccessWithReport("نم إغلاق اليوم بنجاح", shiftId));
      } else {
        emit(UserFailure("لا يوجد يوم عمل مفتوح حالياً"));
      }
    } catch (e) {
      emit(UserFailure("فشل إغلاق اليوم: $e"));
    }
  }

  Future<void> logout() async {
    try {
      await getIt<ActivityLogger>().logActivity(
        type: ActivityType.logout,
        description: 'تسجيل خروج',
        userName: currentUser.name,
      );

      // Create checkpoint on logout
      await CheckpointService().createCheckpoint(
          reason: 'logout_${currentUser.username}', userName: currentUser.name);
    } catch (e) {
      // Audit/checkpoint failures must never trap a user in an active session.
    } finally {
      emit(UserInitial());
    }
  }
}
