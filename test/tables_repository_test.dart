import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/core/data/services/sqlite_manager.dart';
import 'package:grill_pos/features/tables/data/table_models.dart';
import 'package:grill_pos/features/tables/data/tables_repository.dart';

void main() {
  late Directory directory;
  late SQLiteManager manager;
  late TablesRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tables_repository_');
    manager = SQLiteManager(
      databasePath: '${directory.path}${Platform.pathSeparator}tables.db',
    );
    await manager.initialize();
    repository = TablesRepository(database: manager.database);
  });

  tearDown(() async {
    repository.dispose();
    await manager.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('creates unique sequential tables and validates input', () async {
    final first = await repository.createTable(
      name: 'Window',
      capacity: 4,
      section: 'Garden',
    );
    final second = await repository.createTable(
      capacity: 6,
      section: 'Garden',
    );

    expect(second.tableNumber, first.tableNumber + 1);
    expect(first.name, 'Window');
    expect(first.section, 'Garden');

    await expectLater(
      repository.createTable(capacity: 0),
      throwsA(isA<TablesException>()),
    );
    await expectLater(
      repository.createTable(tableNumber: first.tableNumber),
      throwsA(isA<TablesException>()),
    );
  });

  test('manual statuses cannot forge occupancy', () async {
    final table = await repository.createTable(section: 'Main');

    await repository.setStatus(table.id, TableStatus.reserved);
    expect((await repository.getTable(table.id))!.status, TableStatus.reserved);

    await expectLater(
      repository.setStatus(table.id, TableStatus.occupied),
      throwsA(isA<TablesException>()),
    );
  });

  test('metadata edits preserve an active order and lifecycle lock', () async {
    final table = await repository.createTable(section: 'Main');
    await _insertOrder(
      manager,
      id: 'active-table-order',
      tableId: table.id,
      status: 'pending',
    );
    await repository.assignOrder(table.id, 'active-table-order');

    final occupied = (await repository.getTable(table.id))!;
    await repository.updateTable(
      occupied.copyWith(name: 'Family', capacity: 8, section: 'Terrace'),
    );

    final updated = (await repository.getTable(table.id))!;
    expect(updated.name, 'Family');
    expect(updated.capacity, 8);
    expect(updated.section, 'Terrace');
    expect(updated.status, TableStatus.occupied);
    expect(updated.currentOrderId, 'active-table-order');

    await expectLater(
      repository.setStatus(table.id, TableStatus.available),
      throwsA(isA<TablesException>()),
    );
    await expectLater(
      repository.deleteTable(table.id),
      throwsA(isA<TablesException>()),
    );
  });

  test('table with completed order history cannot be deleted', () async {
    final table = await repository.createTable(section: 'Main');
    await _insertOrder(
      manager,
      id: 'historic-table-order',
      tableId: table.id,
      status: 'completed',
    );

    await expectLater(
      repository.deleteTable(table.id),
      throwsA(isA<TablesException>()),
    );
    expect(await repository.getTable(table.id), isNotNull);
  });
}

Future<void> _insertOrder(
  SQLiteManager manager, {
  required String id,
  required String tableId,
  required String status,
}) async {
  final now = DateTime(2026, 7, 19, 12).toIso8601String();
  await manager.database.insert('orders', {
    'id': id,
    'order_number': id,
    'table_id': tableId,
    'status': status,
    'created_at': now,
    'updated_at': now,
  });
}
