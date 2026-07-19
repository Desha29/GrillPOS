import '../../features/auth/data/models/user_model.dart';

enum AppPermission {
  viewDashboard,
  createOrders,
  manageTables,
  viewOrders,
  updateOrders,
  processPayments,
  processRefunds,
  processComputerSales,
  manageRepairs,
  manageInventory,
  manageMenu,
  viewReports,
  manageUsers,
  manageSettings,
  closeBusinessDay,
  backupRestore,
}

extension AppPermissionDetails on AppPermission {
  String get label => switch (this) {
        AppPermission.viewDashboard => 'عرض لوحة التحكم',
        AppPermission.createOrders => 'إنشاء الطلبات',
        AppPermission.manageTables => 'إدارة الطاولات',
        AppPermission.viewOrders => 'عرض الطلبات',
        AppPermission.updateOrders => 'تحديث حالة الطلبات',
        AppPermission.processPayments => 'تحصيل المدفوعات',
        AppPermission.processRefunds => 'تنفيذ المرتجعات',
        AppPermission.processComputerSales => 'مبيعات الكمبيوتر',
        AppPermission.manageRepairs => 'إدارة الصيانة',
        AppPermission.manageInventory => 'إدارة المخزون',
        AppPermission.manageMenu => 'إدارة المنيو',
        AppPermission.viewReports => 'عرض التقارير',
        AppPermission.manageUsers => 'إدارة المستخدمين',
        AppPermission.manageSettings => 'إدارة الإعدادات',
        AppPermission.closeBusinessDay => 'إغلاق الوردية',
        AppPermission.backupRestore => 'النسخ والاستعادة',
      };

  String get group => switch (this) {
        AppPermission.viewDashboard ||
        AppPermission.viewOrders ||
        AppPermission.viewReports =>
          'العرض والتقارير',
        AppPermission.createOrders ||
        AppPermission.manageTables ||
        AppPermission.updateOrders ||
        AppPermission.processPayments ||
        AppPermission.processRefunds =>
          'المبيعات والطلبات',
        AppPermission.processComputerSales ||
        AppPermission.manageRepairs ||
        AppPermission.manageInventory =>
          'مركز الكمبيوتر',
        AppPermission.manageMenu ||
        AppPermission.manageUsers ||
        AppPermission.manageSettings ||
        AppPermission.closeBusinessDay ||
        AppPermission.backupRestore =>
          'الإدارة والنظام',
      };
}

class PermissionDeniedException implements Exception {
  const PermissionDeniedException(this.message, {this.permission});

  final String message;
  final AppPermission? permission;

  @override
  String toString() => message;
}

/// Central least-privilege authorization policy for the local application.
class PermissionGuard {
  PermissionGuard._();

  static const Set<AppPermission> defaultCashierPermissions = {
    AppPermission.viewDashboard,
    AppPermission.createOrders,
    AppPermission.manageTables,
    AppPermission.viewOrders,
    AppPermission.updateOrders,
    AppPermission.processPayments,
    AppPermission.processComputerSales,
    AppPermission.manageRepairs,
  };

  static Set<AppPermission> permissionsFor(User user) {
    if (user.userType == UserType.manager) {
      return Set.unmodifiable(AppPermission.values);
    }
    final custom = user.permissionKeys;
    if (custom == null) return defaultCashierPermissions;
    return Set.unmodifiable(
      AppPermission.values
          .where((permission) => custom.contains(permission.name)),
    );
  }

  static Set<String> keysOf(Iterable<AppPermission> permissions) =>
      permissions.map((permission) => permission.name).toSet();

  static bool can(User user, AppPermission permission) =>
      permissionsFor(user).contains(permission);

  static void require(
    User user,
    AppPermission permission, {
    String? message,
  }) {
    if (can(user, permission)) return;
    throw PermissionDeniedException(
      message ?? 'ليس لديك الصلاحية المطلوبة لتنفيذ هذا الإجراء.',
      permission: permission,
    );
  }

  static AppPermission? permissionForRoute(String routeId) => switch (routeId) {
        'dashboard' => AppPermission.viewDashboard,
        'pos' => AppPermission.createOrders,
        'tables' => AppPermission.manageTables,
        'orders' => AppPermission.viewOrders,
        'computer_sales' => AppPermission.processComputerSales,
        'repairs' => AppPermission.manageRepairs,
        'inventory' => AppPermission.manageInventory,
        'menu' => AppPermission.manageMenu,
        'reports' => AppPermission.viewReports,
        'users' => AppPermission.manageUsers,
        'settings' => AppPermission.manageSettings,
        _ => null,
      };

  static bool canAccessRoute(User user, String routeId) {
    final permission = permissionForRoute(routeId);
    return permission == null || can(user, permission);
  }

  static void checkRouteAccess(User user, String routeId) {
    final permission = permissionForRoute(routeId);
    if (permission == null) return;
    require(
      user,
      permission,
      message: 'لا يسمح دورك الوظيفي بالوصول إلى هذه الشاشة.',
    );
  }

  static void checkRefundPermission(User user) => require(
        user,
        AppPermission.processRefunds,
        message: 'تنفيذ المرتجعات متاح للمدير فقط.',
      );

  static void checkComputerSaleAccess(User user) => require(
        user,
        AppPermission.processComputerSales,
        message: 'Your role cannot create computer quotations or sales.',
      );

  static void checkReportAccess(User user) => require(
        user,
        AppPermission.viewReports,
        message: 'عرض التقارير المالية متاح للمدير فقط.',
      );

  static void checkDayClosePermission(User user) => require(
        user,
        AppPermission.closeBusinessDay,
        message: 'إغلاق يوم العمل متاح للمدير فقط.',
      );
}
