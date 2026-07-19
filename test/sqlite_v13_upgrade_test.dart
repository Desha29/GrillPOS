import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/core/data/services/sqlite_manager.dart';

void main() {
  test('v12 to v13 migration preserves restaurant data', () async {
    final directory =
        await Directory.systemTemp.createTemp('grill_pos_v13_upgrade_');
    final databaseFile =
        File('${directory.path}${Platform.pathSeparator}upgrade.db');
    var manager = SQLiteManager(databasePath: databaseFile.path);

    try {
      await manager.initialize();
      final database = manager.database;
      final timestamp = DateTime(2026, 7, 18).toIso8601String();
      await database.insert('menu_categories', {
        'id': 'migration-marker',
        'name': 'Migration marker',
        'name_ar': 'Migration marker',
        'created_at': timestamp,
        'updated_at': timestamp,
      });

      // Recreate the state of an installed v12 database. Dropping only the
      // v13-owned tables keeps all pre-existing restaurant, repair, and
      // inventory records intact for the real migration callback.
      for (final table in <String>[
        'computer_refunds',
        'computer_return_items',
        'computer_returns',
        'computer_payments',
        'computer_document_item_serials',
        'computer_document_items',
        'computer_documents',
        'computer_document_counters',
      ]) {
        await database.execute('DROP TABLE IF EXISTS $table');
      }
      await database.execute('PRAGMA user_version = 12');
      await manager.close();

      manager = SQLiteManager(databasePath: databaseFile.path);
      await manager.initialize();

      final version = await manager.database.rawQuery('PRAGMA user_version');
      expect(version.single['user_version'], 14);
      expect(
        await manager.database.query(
          'menu_categories',
          where: 'id = ?',
          whereArgs: ['migration-marker'],
        ),
        hasLength(1),
      );

      final userColumns =
          await manager.database.rawQuery('PRAGMA table_info(users)');
      expect(
          userColumns.map((column) => column['name']), contains('permissions'));

      final tables = await manager.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      expect(
        tables.map((row) => row['name']).toSet(),
        containsAll(<String>{
          'computer_documents',
          'computer_document_items',
          'computer_payments',
          'computer_returns',
          'computer_refunds',
        }),
      );
    } finally {
      await manager.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}
