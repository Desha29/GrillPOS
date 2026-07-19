import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/core/security/permission_guard.dart';
import 'package:grill_pos/features/auth/data/models/user_model.dart';

void main() {
  final manager = User(
    username: 'manager',
    name: 'Manager',
    phone: '',
    userType: UserType.manager,
    password: '',
  );
  final cashier = User(
    username: 'cashier',
    name: 'Cashier',
    phone: '',
    userType: UserType.cashier,
    password: '',
  );

  test('manager can access every protected workspace', () {
    for (final permission in AppPermission.values) {
      expect(PermissionGuard.can(manager, permission), isTrue);
    }
    expect(PermissionGuard.canAccessRoute(manager, 'inventory'), isTrue);
  });

  test('cashier has operations access but not management access', () {
    expect(PermissionGuard.canAccessRoute(cashier, 'orders'), isTrue);
    expect(PermissionGuard.canAccessRoute(cashier, 'repairs'), isTrue);
    expect(PermissionGuard.canAccessRoute(cashier, 'computer_sales'), isTrue);
    expect(PermissionGuard.canAccessRoute(cashier, 'inventory'), isFalse);
    expect(PermissionGuard.canAccessRoute(cashier, 'reports'), isFalse);
    expect(
      () => PermissionGuard.checkRouteAccess(cashier, 'inventory'),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('manager-defined custom permissions replace cashier defaults', () {
    final customCashier = User(
      username: 'reports_only',
      name: 'Reports user',
      phone: '',
      userType: UserType.cashier,
      password: '',
      permissionKeys: {
        AppPermission.viewDashboard.name,
        AppPermission.viewReports.name,
      },
    );

    expect(PermissionGuard.canAccessRoute(customCashier, 'dashboard'), isTrue);
    expect(PermissionGuard.canAccessRoute(customCashier, 'reports'), isTrue);
    expect(PermissionGuard.canAccessRoute(customCashier, 'pos'), isFalse);
    expect(PermissionGuard.can(customCashier, AppPermission.manageTables),
        isFalse);
  });

  test('an explicit empty permission set grants no protected access', () {
    final restricted = User(
      username: 'restricted',
      name: 'Restricted',
      phone: '',
      userType: UserType.cashier,
      password: '',
      permissionKeys: <String>{},
    );

    expect(PermissionGuard.permissionsFor(restricted), isEmpty);
    expect(PermissionGuard.canAccessRoute(restricted, 'dashboard'), isFalse);
  });
}
