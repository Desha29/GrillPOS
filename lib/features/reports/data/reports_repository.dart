import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/data/services/persistence_initializer.dart';

class ReportsSummary {
  final double revenue;
  final int ordersCount;
  final double avgOrder;

  const ReportsSummary({
    required this.revenue,
    required this.ordersCount,
    required this.avgOrder,
  });
}

class TopItem {
  final String name;
  final int qty;
  final double revenue;

  const TopItem({required this.name, required this.qty, required this.revenue});
}

class CategorySales {
  final String category;
  final double revenue;

  const CategorySales({required this.category, required this.revenue});
}

class DailyRevenuePoint {
  final String day;
  final double value;

  const DailyRevenuePoint({required this.day, required this.value});
}

class ReportsRepository {
  Database get _db =>
      PersistenceInitializer.persistenceManager!.sqliteManager.database;

  Future<ReportsSummary> getSummary({DateTime? from, DateTime? to}) async {
    final db = _db;
    final range = _whereDateRange(from, to, field: 'created_at');

    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(total_amount), 0) AS revenue,
        COUNT(*) AS orders_count,
        COALESCE(AVG(total_amount), 0) AS avg_order
      FROM orders
      WHERE status = 'completed' ${range.whereClause}
    ''', range.args);

    final row = rows.first;
    return ReportsSummary(
      revenue: (row['revenue'] as num?)?.toDouble() ?? 0,
      ordersCount: (row['orders_count'] as num?)?.toInt() ?? 0,
      avgOrder: (row['avg_order'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<TopItem>> getTopItems(
      {DateTime? from, DateTime? to, int limit = 5}) async {
    final db = _db;
    final range = _whereDateRange(from, to, field: 'o.created_at');

    final rows = await db.rawQuery('''
      SELECT
        oi.item_name AS name,
        COALESCE(SUM(oi.quantity), 0) AS qty,
        COALESCE(SUM(oi.subtotal), 0) AS revenue
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      WHERE o.status = 'completed' ${range.whereClause}
      GROUP BY oi.item_name
      ORDER BY qty DESC
      LIMIT $limit
    ''', range.args);

    return rows
        .map((r) => TopItem(
              name: (r['name'] as String?) ?? 'Unknown',
              qty: (r['qty'] as num?)?.toInt() ?? 0,
              revenue: (r['revenue'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  Future<List<CategorySales>> getSalesByCategory(
      {DateTime? from, DateTime? to}) async {
    final db = _db;
    final range = _whereDateRange(from, to, field: 'o.created_at');

    final rows = await db.rawQuery('''
      SELECT
        mc.name AS category,
        COALESCE(SUM(oi.subtotal), 0) AS revenue
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      LEFT JOIN menu_items mi ON mi.id = oi.menu_item_id
      LEFT JOIN menu_categories mc ON mc.id = mi.category_id
      WHERE o.status = 'completed' ${range.whereClause}
      GROUP BY mc.name
      ORDER BY revenue DESC
    ''', range.args);

    return rows
        .map((r) => CategorySales(
              category: (r['category'] as String?) ?? 'Uncategorized',
              revenue: (r['revenue'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  Future<List<DailyRevenuePoint>> getDailyRevenueTrend({DateTime? from, DateTime? to, int? limit}) async {
    final db = _db;
    final range = _whereDateRange(from, to, field: 'created_at');

    final rows = await db.rawQuery('''
      SELECT
        substr(created_at, 1, 10) AS day,
        COALESCE(SUM(total_amount), 0) AS value
      FROM orders
      WHERE status = 'completed' ${range.whereClause}
      GROUP BY substr(created_at, 1, 10)
      ORDER BY day DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', range.args);

    final list = rows
        .map((r) => DailyRevenuePoint(
              day: (r['day'] as String?) ?? '',
              value: (r['value'] as num?)?.toDouble() ?? 0,
            ))
        .toList();

    return list.reversed.toList();
  }

  _Range _whereDateRange(DateTime? from, DateTime? to,
      {required String field}) {
    if (from == null && to == null) return const _Range('', []);

    final args = <Object?>[];
    final conditions = <String>[];

    if (from != null) {
      conditions.add('$field >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('$field <= ?');
      args.add(to.toIso8601String());
    }

    return _Range(' AND ${conditions.join(' AND ')}', args);
  }
}

class _Range {
  final String whereClause;
  final List<Object?> args;
  const _Range(this.whereClause, this.args);
}
