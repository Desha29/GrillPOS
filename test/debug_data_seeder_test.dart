import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/core/data/services/debug_data_seeder.dart';
import 'package:grill_pos/core/data/services/sqlite_manager.dart';

void main() {
  test('debug seeder covers each module and stays idempotent', () async {
    final directory =
        await Directory.systemTemp.createTemp('grill_pos_debug_seed_');
    final databaseFile =
        File('${directory.path}${Platform.pathSeparator}debug.db');
    final manager = SQLiteManager(databasePath: databaseFile.path);

    try {
      await manager.initialize();
      await DebugDataSeeder.seedDatabase(manager.database);

      Future<int> debugCount(String table) async {
        final rows = await manager.database.rawQuery(
          'SELECT COUNT(*) AS total FROM $table WHERE id LIKE ?',
          ['debug_%'],
        );
        return (rows.single['total'] as num).toInt();
      }

      expect(await debugCount('users'), 2);
      expect(await debugCount('orders'), greaterThanOrEqualTo(8));
      expect(await debugCount('payments'), greaterThanOrEqualTo(7));
      expect(await debugCount('products'), 3);
      expect(await debugCount('repair_tickets'), 2);
      expect(await debugCount('computer_documents'), 1);

      await DebugDataSeeder.seedDatabase(manager.database);
      expect(await debugCount('users'), 2);
      expect(await debugCount('orders'), greaterThanOrEqualTo(8));
      expect(await debugCount('repair_tickets'), 2);
      expect(await debugCount('computer_documents'), 1);
    } finally {
      await manager.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}
