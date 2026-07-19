import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/services/persistence_initializer.dart';
import 'repair_models.dart';

class RepairsRepository {
  RepairsRepository({Database? database}) : _databaseOverride = database;

  static const _uuid = Uuid();
  final _changes = StreamController<void>.broadcast();
  final Database? _databaseOverride;

  Stream<void> get changes => _changes.stream;

  Database get _db =>
      _databaseOverride ??
      PersistenceInitializer.persistenceManager!.sqliteManager.database;

  Future<List<RepairTicket>> getTickets({
    String search = '',
    RepairStatus? status,
  }) async {
    final conditions = <String>[];
    final arguments = <Object?>[];
    final term = search.trim();
    if (term.isNotEmpty) {
      conditions.add('''(
        r.ticket_number LIKE ? OR c.name LIKE ? OR c.phone LIKE ? OR
        r.serial_number LIKE ? OR r.brand LIKE ? OR r.model LIKE ?
      )''');
      final like = '%$term%';
      arguments.addAll(List<Object?>.filled(6, like));
    }
    if (status != null) {
      conditions.add('r.status = ?');
      arguments.add(status.dbValue);
    }

    final rows = await _db.rawQuery('''
      SELECT r.*, c.name AS customer_name, c.phone AS customer_phone
      FROM repair_tickets r
      INNER JOIN customers c ON c.id = r.customer_id
      ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
      ORDER BY
        CASE r.priority WHEN 'urgent' THEN 0 ELSE 1 END,
        r.updated_at DESC
    ''', arguments);
    return rows.map(RepairTicket.fromMap).toList(growable: false);
  }

  Future<RepairStats> getStats() async {
    final rows = await _db.rawQuery('''
      SELECT
        SUM(CASE WHEN status NOT IN ('delivered', 'cancelled') THEN 1 ELSE 0 END) AS open_count,
        SUM(CASE WHEN status = 'ready' THEN 1 ELSE 0 END) AS ready_count,
        SUM(CASE WHEN priority = 'urgent' AND status NOT IN ('delivered', 'cancelled') THEN 1 ELSE 0 END) AS urgent_count,
        SUM(CASE WHEN status != 'cancelled' THEN
          MAX((CASE WHEN final_cost > 0 THEN final_cost ELSE estimated_cost END) - deposit, 0)
          ELSE 0 END) AS balance_due
      FROM repair_tickets
    ''');
    final row = rows.single;
    return RepairStats(
      open: (row['open_count'] as num?)?.toInt() ?? 0,
      ready: (row['ready_count'] as num?)?.toInt() ?? 0,
      urgent: (row['urgent_count'] as num?)?.toInt() ?? 0,
      totalBalanceDue: (row['balance_due'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<RepairTicket> createTicket(NewRepairTicketInput input) async {
    final now = DateTime.now();
    final customerId = _uuid.v4();
    final ticketId = _uuid.v4();
    final ticketNumber = _ticketNumber(now, ticketId);

    await _db.transaction((txn) async {
      await txn.insert('customers', {
        'id': customerId,
        'name': input.customerName.trim(),
        'phone': input.customerPhone.trim(),
        'email': _clean(input.customerEmail),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await txn.insert('repair_tickets', {
        'id': ticketId,
        'ticket_number': ticketNumber,
        'customer_id': customerId,
        'device_type': input.deviceType.trim(),
        'brand': _clean(input.brand),
        'model': _clean(input.model),
        'serial_number': _clean(input.serialNumber),
        'accessories': _clean(input.accessories),
        'reported_issue': input.reportedIssue.trim(),
        'status': RepairStatus.received.dbValue,
        'priority': input.priority.dbValue,
        'estimated_cost': input.estimatedCost,
        'final_cost': 0.0,
        'deposit': input.deposit,
        'due_date': input.dueDate?.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await txn.insert('repair_history', {
        'id': _uuid.v4(),
        'ticket_id': ticketId,
        'new_status': RepairStatus.received.dbValue,
        'note': 'Repair ticket created',
        'created_at': now.toIso8601String(),
      });
    });
    _notify();

    final tickets = await getTickets(search: ticketNumber);
    return tickets.single;
  }

  Future<void> updateTicket(
    RepairTicket ticket, {
    String? changedBy,
  }) async {
    final currentRows = await _db.query(
      'repair_tickets',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [ticket.id],
      limit: 1,
    );
    if (currentRows.isEmpty) throw StateError('Repair ticket was not found.');
    final previousStatus = currentRows.first['status'] as String?;
    final values = ticket.toMap()
      ..remove('id')
      ..remove('ticket_number')
      ..remove('created_at');

    await _db.transaction((txn) async {
      await txn.update(
        'repair_tickets',
        values,
        where: 'id = ?',
        whereArgs: [ticket.id],
      );
      if (previousStatus != ticket.status.dbValue) {
        await txn.insert('repair_history', {
          'id': _uuid.v4(),
          'ticket_id': ticket.id,
          'previous_status': previousStatus,
          'new_status': ticket.status.dbValue,
          'changed_by': changedBy,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  String _ticketNumber(DateTime now, String id) {
    final date = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'REP-$date-${id.substring(0, 6).toUpperCase()}';
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  void dispose() => _changes.close();
}
