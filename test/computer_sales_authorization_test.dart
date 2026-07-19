import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/features/auth/data/models/user_model.dart';
import 'package:grill_pos/features/computer_sales/data/computer_sales_models.dart';
import 'package:grill_pos/features/computer_sales/data/computer_sales_repository.dart';
import 'package:grill_pos/features/computer_sales/presentation/cubit/computer_sales_cubit.dart';

void main() {
  test('cashier cannot bypass manager return authorization with forged actor',
      () async {
    final repository = ComputerSalesRepository();
    final cubit = ComputerSalesCubit(
      repository,
      currentUser: () => User(
        username: 'cashier-1',
        name: 'Cashier',
        phone: '',
        userType: UserType.cashier,
        password: '',
      ),
    );

    try {
      final result = await cubit.createReturn(
        const SaleReturnInput(
          saleId: 'sale-1',
          lines: [],
          createdBy: 'forged-manager',
        ),
      );

      expect(result, isNull);
      expect(cubit.state.error, contains('managers only'));
    } finally {
      await cubit.close();
      repository.dispose();
    }
  });
}
