
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

class UserCubit extends Cubit<UserStates> {
  UserCubit({
    required this.userRepository,

  }) : super(UserInitial());

  final UserRepositoryInt userRepository;


  static UserCubit get(context) => BlocProvider.of(context);
  late User currentUser;
  bool _isPasswordVisible = false;

  bool get isPasswordVisible => _isPasswordVisible;

  List<User> _users = [];
  List<User> get allUsers => _users; 
  List<User> get users => _users; // Access cached users even if state is not Loaded

  void getAllUsers() async {
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
          );
          await userRepository.saveUser(defaultAdmin);
          getAllUsers(); // Retry loading
          return;
        }

        // Sort: Managers first
        usersList.sort((a, b) {
           if (a.userType == UserType.manager && b.userType != UserType.manager) return -1;
           if (a.userType != UserType.manager && b.userType == UserType.manager) return 1;
           return 0;
        });
        _users = usersList;
        emit(UsersLoaded(usersList));
      },
    );
  }

 void deleteUser(String username) async {
  emit(UserLoading());
  final result = await userRepository.deleteUser(username);
  result.fold(
    (failure) => emit(UserFailure(failure.message)),
    (_) async {
      emit(UserSuccess("تم حذف المستخدم بنجاح"));
      
   
      await getIt<ActivityLogger>().logActivity(
        type: ActivityType.userDelete,
        description: 'حذف مستخدم: $username',
        userName: currentUser.name,
     
      );
      
      getAllUsers(); 
    },
  );
}

void saveUser(User user) async {
  emit(UserLoading());
  final result = await userRepository.saveUser(user);
  result.fold(
    (failure) => emit(UserFailure(failure.message)),
    (_) async {
      emit(UserSuccess("تم إضافة المستخدم بنجاح"));
      
      final isUpdate = _users.any((u) => u.username == user.username);

      // Log activity with session (auto-creates session if closed)

      await getIt<ActivityLogger>().logActivity(
        type: isUpdate ? ActivityType.userUpdate : ActivityType.userAdd,
        description: isUpdate ? 'تحديث مستخدم: ${user.name}' : 'إضافة مستخدم: ${user.name}',
        userName: currentUser.name,

      );
      
      getAllUsers(); 
    },
  );
}
void updateUser(User user) async {
  emit(UserLoading());
  final result = await userRepository.updateUser(user);
  result.fold(
    (failure) => emit(UserFailure(failure.message)),
    (_) async {
      if (currentUser.username == user.username) {
        currentUser = user;
      }
      emit(UserSuccess("تم تحديث المستخدم بنجاح"));
      
      // Log activity with session (auto-creates session if closed)

      await getIt<ActivityLogger>().logActivity(
        type: ActivityType.userUpdate,
        description: 'تحديث مستخدم: ${user.name}',
        userName: currentUser.name,
    
      );
      
      getAllUsers(); 
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
        print("🔐 Login Attempt: '$trimmedUsername'");
        print("   Input Password: '$trimmedPassword'");
        print("   Stored Password: '${user.password}'");
        
        if (user.password == trimmedPassword) {
          currentUser = user;
          try {
       
           
             
             // Log activity
             await getIt<ActivityLogger>().logActivity(
               type: ActivityType.login,
               description: 'تسجيل دخول',
               userName: user.name,
         
             );

             // Create checkpoint on login
             await CheckpointService().createCheckpoint(
               reason: 'login_${user.username}', 
               userName: user.name
             );
             
             await _checkAndOpenSession();

             emit(UserSuccess("تم تسجيل الدخول بنجاح"));
        
          } catch (e, stack) { print(e); print(stack);
             emit(UserFailure("فشل فتح اليوم: $e"));
          }
        } else {
          print("   ❌ Password Mismatch!");
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
    emit(CloseSessionLoading());
    try {
      final db = PersistenceInitializer.persistenceManager!.sqliteManager;
      final res = await db.query('shifts', where: 'is_open = 1', limit: 1);
      if (res.isNotEmpty) {
        final shiftId = res.first['id'] as String;
        await db.update('shifts', {
          'is_open': 0,
          'close_time': DateTime.now().toIso8601String(),
          'closed_by': currentUser.username,
        }, where: 'id = ?', whereArgs: [shiftId]);

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

  void logout() async {
    try {

      await getIt<ActivityLogger>().logActivity(
        type: ActivityType.logout,
        description: 'تسجيل خروج',
        userName: currentUser.name,
  
      );

      // Create checkpoint on logout
      await CheckpointService().createCheckpoint(
        reason: 'logout_${currentUser.username}', 
        userName: currentUser.name
      );

   

      emit(UserInitial());
    } catch (e) {
      emit(UserFailure("فشل تسجيل الخروج: $e"));
    }
  }

}
   
   
      


   

     
  
