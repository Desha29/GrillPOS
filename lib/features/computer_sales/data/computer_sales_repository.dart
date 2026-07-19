import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/services/persistence_initializer.dart';
import 'computer_sales_models.dart';

class ComputerSalesException implements Exception {
  const ComputerSalesException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ComputerSalesRepository {
  ComputerSalesRepository({Database? database}) : _databaseOverride = database;

  static const _uuid = Uuid();
  static const _moneyTolerance = 0.005;

  final Database? _databaseOverride;
  final _changes = StreamController<void>.broadcast();

  Database get _db =>
      _databaseOverride ??
      PersistenceInitializer.persistenceManager!.sqliteManager.database;

  Stream<void> get changes => _changes.stream;

  Future<List<ComputerCustomer>> searchCustomers({String search = ''}) async {
    final term = search.trim();
    final rows = await _db.query(
      'customers',
      where:
          term.isEmpty ? null : '(name LIKE ? OR phone LIKE ? OR email LIKE ?)',
      whereArgs: term.isEmpty ? null : List<Object?>.filled(3, '%$term%'),
      orderBy: 'updated_at DESC, name',
      limit: 100,
    );
    return rows.map(ComputerCustomer.fromMap).toList(growable: false);
  }

  Future<ComputerCustomer> createCustomer(
    NewComputerCustomerInput input,
  ) async {
    final name = input.name.trim();
    final phone = input.phone.trim();
    if (name.isEmpty) {
      throw const ComputerSalesException('Customer name is required.');
    }
    if (phone.isEmpty) {
      throw const ComputerSalesException('Customer phone is required.');
    }

    final existing = await _db.query(
      'customers',
      where: 'phone = ?',
      whereArgs: [phone],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw const ComputerSalesException(
        'A customer with this phone number already exists.',
      );
    }

    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await _db.insert('customers', {
      'id': id,
      'name': name,
      'phone': phone,
      'email': _clean(input.email),
      'address': _clean(input.address),
      'notes': _clean(input.notes),
      'created_at': now,
      'updated_at': now,
    });
    _notify();
    final row = await _db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return ComputerCustomer.fromMap(row.single);
  }

  Future<List<SaleableProduct>> getSaleableProducts({
    String search = '',
  }) async {
    final conditions = <String>[
      'is_active = 1',
      "product_type = 'merchandise'",
    ];
    final arguments = <Object?>[];
    final term = search.trim();
    if (term.isNotEmpty) {
      conditions.add('''(
        name LIKE ? OR sku LIKE ? OR barcode LIKE ? OR brand LIKE ? OR model LIKE ?
      )''');
      arguments.addAll(List<Object?>.filled(5, '%$term%'));
    }
    final rows = await _db.query(
      'products',
      where: conditions.join(' AND '),
      whereArgs: arguments,
      orderBy: 'name',
      limit: 200,
    );
    return rows.map(SaleableProduct.fromMap).toList(growable: false);
  }

  Future<List<AvailableSerial>> getAvailableSerials(
    String productId, {
    String? forQuotationId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final rows = await _db.rawQuery('''
      SELECT s.id, s.product_id, s.serial_number, s.purchase_cost
      FROM product_serials s
      WHERE s.product_id = ? AND s.status = 'in_stock'
        AND NOT EXISTS (
          SELECT 1
          FROM computer_document_item_serials reserved
          INNER JOIN computer_document_items i
            ON i.id = reserved.document_item_id
          INNER JOIN computer_documents d ON d.id = i.document_id
          WHERE reserved.serial_id = s.id
            AND d.document_type = 'quotation'
            AND d.status = 'draft'
            AND (d.expiry_date IS NULL OR
              julianday(d.expiry_date) >= julianday(?))
            ${forQuotationId == null ? '' : 'AND d.id <> ?'}
        )
      ORDER BY s.created_at, s.serial_number
    ''', [productId, now, if (forQuotationId != null) forQuotationId]);
    return rows.map(AvailableSerial.fromMap).toList(growable: false);
  }

  Future<ComputerDocument> createDraftQuotation(
    DraftQuotationInput input,
  ) async {
    _validateQuotationInput(input);
    final now = DateTime.now();
    final id = _uuid.v4();

    await _db.transaction((txn) async {
      await _ensureCustomerExists(txn, input.customerId);
      final products = await _validateAndLoadProducts(txn, input.lines);
      final totals = _calculateTotals(input, products);
      final number = await _nextDocumentNumber(txn, 'QUO', now);

      await txn.insert('computer_documents', {
        'id': id,
        'document_number': number,
        'document_type': ComputerDocumentType.quotation.dbValue,
        'status': ComputerDocumentStatus.draft.dbValue,
        'customer_id': input.customerId,
        'subtotal': totals.subtotal,
        'discount_amount': input.discountAmount,
        'tax_rate': input.taxRate,
        'tax_amount': totals.tax,
        'total_amount': totals.total,
        'paid_amount': 0.0,
        'refunded_amount': 0.0,
        'balance_due': totals.total,
        'payment_status': ComputerPaymentStatus.unpaid.dbValue,
        'expiry_date': input.expiryDate.toIso8601String(),
        'notes': _clean(input.notes),
        'created_by': input.createdBy,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await _insertQuotationLines(txn, id, input.lines, products, now);
    });
    _notify();
    return getDocument(id);
  }

  Future<ComputerDocument> updateDraftQuotation(
    String quotationId,
    DraftQuotationInput input,
  ) async {
    _validateQuotationInput(input);
    final now = DateTime.now();
    await _db.transaction((txn) async {
      final quotation = await _getDocumentRow(txn, quotationId);
      _ensureDraftQuotation(quotation);
      await _ensureCustomerExists(txn, input.customerId);
      final products = await _validateAndLoadProducts(
        txn,
        input.lines,
        forQuotationId: quotationId,
      );
      final totals = _calculateTotals(input, products);

      await txn.delete(
        'computer_document_items',
        where: 'document_id = ?',
        whereArgs: [quotationId],
      );
      await txn.update(
        'computer_documents',
        {
          'customer_id': input.customerId,
          'subtotal': totals.subtotal,
          'discount_amount': input.discountAmount,
          'tax_rate': input.taxRate,
          'tax_amount': totals.tax,
          'total_amount': totals.total,
          'balance_due': totals.total,
          'expiry_date': input.expiryDate.toIso8601String(),
          'notes': _clean(input.notes),
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [quotationId],
      );
      await _insertQuotationLines(
        txn,
        quotationId,
        input.lines,
        products,
        now,
      );
    });
    _notify();
    return getDocument(quotationId);
  }

  Future<void> cancelQuotation(String quotationId) async {
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      final quotation = await _getDocumentRow(txn, quotationId);
      _ensureDraftQuotation(quotation);
      await txn.update(
        'computer_documents',
        {
          'status': ComputerDocumentStatus.cancelled.dbValue,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [quotationId],
      );
    });
    _notify();
  }

  Future<List<ComputerDocument>> listDocuments({
    String search = '',
    ComputerDocumentType? type,
    ComputerDocumentStatus? status,
    ComputerPaymentStatus? paymentStatus,
    DateTime? from,
    DateTime? to,
    int limit = 250,
  }) async {
    final conditions = <String>[];
    final arguments = <Object?>[];
    final term = search.trim();
    if (term.isNotEmpty) {
      conditions.add('''(
        d.document_number LIKE ? OR c.name LIKE ? OR c.phone LIKE ? OR
        EXISTS (
          SELECT 1 FROM computer_document_items i
          WHERE i.document_id = d.id
            AND (i.product_name LIKE ? OR i.sku LIKE ?)
        )
      )''');
      arguments.addAll(List<Object?>.filled(5, '%$term%'));
    }
    if (type != null) {
      conditions.add('d.document_type = ?');
      arguments.add(type.dbValue);
    }
    if (status != null) {
      conditions.add('d.status = ?');
      arguments.add(status.dbValue);
    }
    if (paymentStatus != null) {
      conditions.add('d.payment_status = ?');
      arguments.add(paymentStatus.dbValue);
    }
    if (from != null) {
      conditions.add('d.created_at >= ?');
      arguments.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('d.created_at <= ?');
      arguments.add(to.toIso8601String());
    }

    final rows = await _db.rawQuery('''
      SELECT d.*, c.name AS customer_name, c.phone AS customer_phone
      FROM computer_documents d
      INNER JOIN customers c ON c.id = d.customer_id
      ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
      ORDER BY d.created_at DESC
      LIMIT ?
    ''', [...arguments, limit]);
    return rows.map(ComputerDocument.fromMap).toList(growable: false);
  }

  Future<ComputerDocument> getDocument(String id) async {
    final rows = await _db.rawQuery('''
      SELECT d.*, c.name AS customer_name, c.phone AS customer_phone
      FROM computer_documents d
      INNER JOIN customers c ON c.id = d.customer_id
      WHERE d.id = ?
      LIMIT 1
    ''', [id]);
    if (rows.isEmpty) {
      throw const ComputerSalesException('Document was not found.');
    }

    final itemRows = await _db.query(
      'computer_document_items',
      where: 'document_id = ?',
      whereArgs: [id],
      orderBy: 'created_at, rowid',
    );
    final lines = <ComputerDocumentLine>[];
    for (final item in itemRows) {
      final serialRows = await _db.rawQuery('''
        SELECT s.id, s.product_id, s.serial_number, s.purchase_cost
        FROM computer_document_item_serials dis
        INNER JOIN product_serials s ON s.id = dis.serial_id
        WHERE dis.document_item_id = ?
        ORDER BY s.serial_number
      ''', [item['id']]);
      lines.add(ComputerDocumentLine.fromMap(
        item,
        serials:
            serialRows.map(AvailableSerial.fromMap).toList(growable: false),
      ));
    }
    final paymentRows = await _db.query(
      'computer_payments',
      where: 'document_id = ?',
      whereArgs: [id],
      orderBy: 'created_at',
    );
    return ComputerDocument.fromMap(
      rows.single,
      lines: lines,
      payments:
          paymentRows.map(ComputerPayment.fromMap).toList(growable: false),
    );
  }

  Future<ComputerSalesStats> getStats() async {
    final documentRows = await _db.rawQuery('''
      SELECT
        SUM(CASE WHEN document_type = 'quotation' AND status = 'draft'
          THEN 1 ELSE 0 END) AS draft_quotations,
        SUM(CASE WHEN document_type = 'sale' AND status IN
          ('completed', 'partially_returned', 'returned')
          THEN 1 ELSE 0 END) AS completed_sales,
        COALESCE(SUM(CASE WHEN document_type = 'sale'
          THEN total_amount ELSE 0 END), 0) AS revenue,
        COALESCE(SUM(CASE WHEN document_type = 'sale'
          THEN balance_due ELSE 0 END), 0) AS balance_due
      FROM computer_documents
    ''');
    final returnRows = await _db.rawQuery(
      'SELECT COALESCE(SUM(refund_amount), 0) AS returned_value FROM computer_returns',
    );
    final document = documentRows.single;
    return ComputerSalesStats(
      draftQuotations: (document['draft_quotations'] as num?)?.toInt() ?? 0,
      completedSales: (document['completed_sales'] as num?)?.toInt() ?? 0,
      salesRevenue: (document['revenue'] as num?)?.toDouble() ?? 0,
      balanceDue: (document['balance_due'] as num?)?.toDouble() ?? 0,
      returnedValue:
          (returnRows.single['returned_value'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<ComputerDocument> convertQuotation(
    String quotationId, {
    List<PaymentInput> payments = const [],
    String? createdBy,
  }) async {
    final now = DateTime.now();
    late String saleId;
    await _db.transaction((txn) async {
      final quotation = await _getDocumentRow(txn, quotationId);
      _ensureDraftQuotation(quotation);
      final expiry =
          DateTime.tryParse(quotation['expiry_date'] as String? ?? '');
      if (expiry != null && expiry.isBefore(now)) {
        throw const ComputerSalesException(
          'This quotation has expired. Update its expiry date before converting.',
        );
      }

      final total = (quotation['total_amount'] as num).toDouble();
      final paid = _validatePayments(payments, maximum: total);
      final items = await txn.query(
        'computer_document_items',
        where: 'document_id = ?',
        whereArgs: [quotationId],
        orderBy: 'created_at, rowid',
      );
      if (items.isEmpty) {
        throw const ComputerSalesException(
          'A quotation must contain at least one product.',
        );
      }

      saleId = _uuid.v4();
      final saleNumber = await _nextDocumentNumber(txn, 'SAL', now);
      final balance = _money(total - paid);
      final paymentStatus = _derivePaymentStatus(
        netPaid: paid,
        balanceDue: balance,
        refunded: 0,
        saleStatus: ComputerDocumentStatus.completed,
      );
      await txn.insert('computer_documents', {
        'id': saleId,
        'document_number': saleNumber,
        'document_type': ComputerDocumentType.sale.dbValue,
        'status': ComputerDocumentStatus.completed.dbValue,
        'customer_id': quotation['customer_id'],
        'source_quotation_id': quotationId,
        'subtotal': quotation['subtotal'],
        'discount_amount': quotation['discount_amount'],
        'tax_rate': quotation['tax_rate'],
        'tax_amount': quotation['tax_amount'],
        'total_amount': total,
        'paid_amount': paid,
        'refunded_amount': 0.0,
        'balance_due': balance,
        'payment_status': paymentStatus.dbValue,
        'notes': quotation['notes'],
        'created_by': createdBy ?? quotation['created_by'],
        'completed_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      for (final quoteItem in items) {
        await _convertLine(
          txn,
          quoteItem: quoteItem,
          saleId: saleId,
          customerId: quotation['customer_id'] as String,
          quotationId: quotationId,
          completedAt: now,
          createdBy: createdBy,
        );
      }
      for (final payment in payments) {
        await _insertPayment(txn, saleId, payment, now);
      }
      final insertedPaymentTotal = await _sumPayments(txn, saleId);
      if (!_sameMoney(insertedPaymentTotal, paid)) {
        throw const ComputerSalesException(
          'Payment totals could not be reconciled. The sale was not created.',
        );
      }
      await txn.update(
        'computer_documents',
        {
          'status': ComputerDocumentStatus.converted.dbValue,
          'converted_sale_id': saleId,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [quotationId],
      );
    });
    _notify();
    return getDocument(saleId);
  }

  Future<ComputerDocument> addPayment(
    String saleId,
    PaymentInput payment,
  ) async {
    final now = DateTime.now();
    await _db.transaction((txn) async {
      final sale = await _getDocumentRow(txn, saleId);
      _ensureReturnableSale(sale);
      final amount = _normalizedPaymentAmount(payment.amount, 'Payment');
      final total = (sale['total_amount'] as num).toDouble();
      final returnedValue = await _sumReturnValue(txn, saleId);
      final effectiveTotal = _money((total - returnedValue).clamp(0, total));
      final paidBefore = await _sumPayments(txn, saleId);
      final refunded = await _sumRefunds(txn, saleId);
      final netPaidBefore =
          _money((paidBefore - refunded).clamp(0, paidBefore));
      final balanceBefore =
          _money((effectiveTotal - netPaidBefore).clamp(0, effectiveTotal));
      if (amount > balanceBefore + _moneyTolerance) {
        throw const ComputerSalesException(
          'Payment cannot be greater than the outstanding balance.',
        );
      }
      await _insertPayment(txn, saleId, payment, now);
      final paid = await _sumPayments(txn, saleId);
      if (!_sameMoney(paid, paidBefore + amount)) {
        throw const ComputerSalesException(
          'Payment totals could not be reconciled. No payment was recorded.',
        );
      }
      final netPaid = _money((paid - refunded).clamp(0, paid));
      final newBalance =
          _money((effectiveTotal - netPaid).clamp(0, effectiveTotal));
      final status = _derivePaymentStatus(
        netPaid: netPaid,
        balanceDue: newBalance,
        refunded: refunded,
        saleStatus: ComputerDocumentStatusX.fromDb(sale['status'] as String?),
      );
      await txn.update(
        'computer_documents',
        {
          'paid_amount': paid,
          'refunded_amount': refunded,
          'balance_due': newBalance,
          'payment_status': status.dbValue,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
    _notify();
    return getDocument(saleId);
  }

  Future<ComputerReturn> createReturn(SaleReturnInput input) async {
    if (input.lines.isEmpty) {
      throw const ComputerSalesException(
        'Select at least one product to return.',
      );
    }
    final duplicateItems = input.lines.map((line) => line.saleItemId).toList();
    if (duplicateItems.toSet().length != duplicateItems.length) {
      throw const ComputerSalesException(
        'A sale line can only appear once in a return.',
      );
    }

    final now = DateTime.now();
    final returnId = _uuid.v4();
    await _db.transaction((txn) async {
      final sale = await _getDocumentRow(txn, input.saleId);
      _ensureReturnableSale(sale);
      final saleSubtotal = (sale['subtotal'] as num).toDouble();
      final saleTotal = (sale['total_amount'] as num).toDouble();
      final allocationFactor =
          saleSubtotal <= _moneyTolerance ? 0.0 : saleTotal / saleSubtotal;

      final prepared = <_PreparedReturnLine>[];
      for (final line in input.lines) {
        prepared.add(await _prepareReturnLine(
          txn,
          saleId: input.saleId,
          input: line,
          allocationFactor: allocationFactor,
        ));
      }
      final calculatedReturnValue = _money(
        prepared.fold<double>(0, (sum, line) => sum + line.refundAmount),
      );
      final existingReturnRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(refund_amount), 0) AS value FROM computer_returns WHERE sale_id = ?',
        [input.saleId],
      );
      final existingReturnValue =
          (existingReturnRows.single['value'] as num).toDouble();
      final remainingRows = await txn.rawQuery('''
        SELECT COALESCE(SUM(quantity - returned_quantity), 0) AS quantity
        FROM computer_document_items
        WHERE document_id = ?
      ''', [input.saleId]);
      final remainingQuantity =
          (remainingRows.single['quantity'] as num).toDouble();
      final selectedQuantity = prepared.fold<double>(
        0,
        (sum, line) => sum + line.quantity,
      );
      final completesReturn =
          selectedQuantity >= remainingQuantity - _moneyTolerance;
      final returnValue = completesReturn
          ? _money((saleTotal - existingReturnValue).clamp(0, saleTotal))
          : calculatedReturnValue;
      var unallocatedReturnValue = returnValue;
      for (var index = 0; index < prepared.length; index++) {
        final line = prepared[index];
        final proposed = index == prepared.length - 1
            ? unallocatedReturnValue
            : _money(line.refundAmount);
        final allocated = proposed > unallocatedReturnValue
            ? unallocatedReturnValue
            : proposed;
        prepared[index] = _PreparedReturnLine(
          item: line.item,
          quantity: line.quantity,
          serialIds: line.serialIds,
          refundAmount: allocated,
        );
        unallocatedReturnValue = _money(unallocatedReturnValue - allocated);
      }
      final paid = await _sumPayments(txn, input.saleId);
      final existingRefunded = await _sumRefunds(txn, input.saleId);
      final netPaidBefore = _money((paid - existingRefunded).clamp(0, paid));
      final effectiveTotalBefore =
          _money((saleTotal - existingReturnValue).clamp(0, saleTotal));
      final existingCustomerCredit = _money(
          (netPaidBefore - effectiveTotalBefore).clamp(0, netPaidBefore));
      if (existingCustomerCredit > _moneyTolerance) {
        throw ComputerSalesException(
          'This sale already has an unresolved customer credit of '
          '${existingCustomerCredit.toStringAsFixed(2)}. Refund that credit '
          'before processing another return.',
        );
      }
      final effectiveTotalAfter = _money(
        (effectiveTotalBefore - returnValue).clamp(0, effectiveTotalBefore),
      );
      final requiredRefund = _money(
        (netPaidBefore - effectiveTotalAfter).clamp(0, netPaidBefore),
      );
      final refundPaid = _validatePayments(
        input.refunds,
        noun: 'Refund',
      );
      if (!_sameMoney(refundPaid, requiredRefund)) {
        throw ComputerSalesException(
          'This return requires refund payments totaling exactly '
          '${requiredRefund.toStringAsFixed(2)} to clear the customer credit '
          'created by this return. The unpaid portion only reduces the '
          'outstanding balance.',
        );
      }

      final returnNumber = await _nextDocumentNumber(txn, 'RET', now);
      await txn.insert('computer_returns', {
        'id': returnId,
        'return_number': returnNumber,
        'sale_id': input.saleId,
        'refund_amount': returnValue,
        'reason': _clean(input.reason),
        'created_by': input.createdBy,
        'created_at': now.toIso8601String(),
      });

      for (final line in prepared) {
        await _applyReturnLine(
          txn,
          returnId: returnId,
          line: line,
          createdAt: now,
          createdBy: input.createdBy,
        );
      }
      final returnItemRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(refund_amount), 0) AS value FROM computer_return_items WHERE return_id = ?',
        [returnId],
      );
      final allocatedReturnValue =
          _money((returnItemRows.single['value'] as num).toDouble());
      if (!_sameMoney(allocatedReturnValue, returnValue)) {
        throw const ComputerSalesException(
          'Return item totals could not be reconciled. The return was cancelled.',
        );
      }
      for (final refund in input.refunds) {
        await txn.insert('computer_refunds', {
          'id': _uuid.v4(),
          'return_id': returnId,
          'amount': _normalizedPaymentAmount(refund.amount, 'Refund'),
          'method': refund.method.dbValue,
          'reference_number': _clean(refund.referenceNumber),
          'notes': _clean(refund.notes),
          'processed_by': refund.receivedBy ?? input.createdBy,
          'created_at': now.toIso8601String(),
        });
      }

      final returnedRows = await txn.rawQuery('''
        SELECT
          COALESCE(SUM(quantity), 0) AS sold_quantity,
          COALESCE(SUM(returned_quantity), 0) AS returned_quantity
        FROM computer_document_items
        WHERE document_id = ?
      ''', [input.saleId]);
      final quantities = returnedRows.single;
      final soldQuantity = (quantities['sold_quantity'] as num).toDouble();
      final returnedQuantity =
          (quantities['returned_quantity'] as num).toDouble();
      final saleStatus = returnedQuantity >= soldQuantity - _moneyTolerance
          ? ComputerDocumentStatus.returned
          : ComputerDocumentStatus.partiallyReturned;

      final totalReturnedValue = await _sumReturnValue(txn, input.saleId);
      final newRefunded = await _sumRefunds(txn, input.saleId);
      if (!_sameMoney(newRefunded, existingRefunded + requiredRefund)) {
        throw const ComputerSalesException(
          'Refund totals could not be reconciled. The return was cancelled.',
        );
      }
      final effectiveTotal =
          _money((saleTotal - totalReturnedValue).clamp(0, saleTotal));
      final netPaid = _money((paid - newRefunded).clamp(0, paid));
      final balance =
          _money((effectiveTotal - netPaid).clamp(0, effectiveTotal));
      if (netPaid > effectiveTotal + _moneyTolerance) {
        throw const ComputerSalesException(
          'This return would leave an unresolved customer credit. The return '
          'was cancelled without changing stock.',
        );
      }
      final paymentStatus = _derivePaymentStatus(
        netPaid: netPaid,
        balanceDue: balance,
        refunded: newRefunded,
        saleStatus: saleStatus,
      );
      await txn.update(
        'computer_documents',
        {
          'status': saleStatus.dbValue,
          'paid_amount': paid,
          'refunded_amount': newRefunded,
          'balance_due': balance,
          'payment_status': paymentStatus.dbValue,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [input.saleId],
      );
    });
    _notify();
    return (await listReturns(saleId: input.saleId))
        .firstWhere((item) => item.id == returnId);
  }

  Future<List<ComputerReturn>> listReturns({String? saleId}) async {
    final rows = await _db.rawQuery('''
      SELECT r.*, d.document_number AS sale_number,
        c.name AS customer_name
      FROM computer_returns r
      INNER JOIN computer_documents d ON d.id = r.sale_id
      INNER JOIN customers c ON c.id = d.customer_id
      ${saleId == null ? '' : 'WHERE r.sale_id = ?'}
      ORDER BY r.created_at DESC
    ''', saleId == null ? const [] : [saleId]);
    final results = <ComputerReturn>[];
    for (final row in rows) {
      final lineRows = await _db.rawQuery('''
        SELECT ri.*, i.product_name, s.serial_number
        FROM computer_return_items ri
        INNER JOIN computer_document_items i ON i.id = ri.sale_item_id
        LEFT JOIN product_serials s ON s.id = ri.serial_id
        WHERE ri.return_id = ?
        ORDER BY ri.rowid
      ''', [row['id']]);
      final refundRows = await _db.query(
        'computer_refunds',
        where: 'return_id = ?',
        whereArgs: [row['id']],
        orderBy: 'created_at, rowid',
      );
      results.add(ComputerReturn.fromMap(
        row,
        lines: lineRows.map(ComputerReturnLine.fromMap).toList(growable: false),
        refunds: refundRows.map(ComputerRefund.fromMap).toList(growable: false),
      ));
    }
    return results;
  }

  Future<void> _insertQuotationLines(
    DatabaseExecutor txn,
    String documentId,
    List<QuotationLineInput> inputs,
    Map<String, Map<String, Object?>> products,
    DateTime now,
  ) async {
    for (final input in inputs) {
      final product = products[input.productId]!;
      final itemId = _uuid.v4();
      final warrantyMonths = input.warrantyMonths ??
          (product['warranty_months'] as num?)?.toInt() ??
          0;
      await txn.insert('computer_document_items', {
        'id': itemId,
        'document_id': documentId,
        'product_id': input.productId,
        'product_name': product['name'],
        'sku': product['sku'],
        'quantity': input.quantity,
        'unit_price': input.unitPrice,
        'unit_cost': product['cost'],
        'line_subtotal': _money(input.quantity * input.unitPrice),
        'warranty_months': warrantyMonths,
        'returned_quantity': 0.0,
        'track_serials': product['track_serials'],
        'created_at': now.toIso8601String(),
      });
      for (final serialId in input.serialIds.toSet()) {
        await txn.insert('computer_document_item_serials', {
          'document_item_id': itemId,
          'serial_id': serialId,
        });
      }
    }
  }

  Future<void> _convertLine(
    Transaction txn, {
    required Map<String, Object?> quoteItem,
    required String saleId,
    required String customerId,
    required String quotationId,
    required DateTime completedAt,
    String? createdBy,
  }) async {
    final productId = quoteItem['product_id'] as String;
    final productRows = await txn.query(
      'products',
      where: 'id = ? AND is_active = 1',
      whereArgs: [productId],
      limit: 1,
    );
    if (productRows.isEmpty) {
      throw ComputerSalesException(
        '${quoteItem['product_name']} is no longer available.',
      );
    }
    final product = productRows.single;
    final quantity = (quoteItem['quantity'] as num).toDouble();
    final currentStock = (product['stock'] as num).toDouble();
    if (currentStock + _moneyTolerance < quantity) {
      throw ComputerSalesException(
        'Not enough stock for ${quoteItem['product_name']}. '
        'Available: ${_quantityText(currentStock)}.',
      );
    }
    final tracksSerials = (product['track_serials'] as num?)?.toInt() == 1;
    final warrantyMonths = (quoteItem['warranty_months'] as num?)?.toInt() ?? 0;
    final warrantyExpiry = warrantyMonths <= 0
        ? null
        : _addMonths(completedAt, warrantyMonths).toIso8601String();
    final serials = tracksSerials
        ? await _selectSerials(
            txn,
            quoteItemId: quoteItem['id'] as String,
            productId: productId,
            quantity: quantity,
            quotationId: quotationId,
          )
        : const <Map<String, Object?>>[];
    final currentProductCost = (product['cost'] as num?)?.toDouble() ?? 0.0;
    final saleUnitCost = tracksSerials && serials.isNotEmpty
        ? serials.fold<double>(
              0,
              (sum, serial) =>
                  sum +
                  ((serial['purchase_cost'] as num?)?.toDouble() ??
                      currentProductCost),
            ) /
            serials.length
        : currentProductCost;

    final saleItemId = _uuid.v4();
    await txn.insert('computer_document_items', {
      'id': saleItemId,
      'document_id': saleId,
      'product_id': productId,
      'product_name': quoteItem['product_name'],
      'sku': quoteItem['sku'],
      'quantity': quantity,
      'unit_price': quoteItem['unit_price'],
      'unit_cost': saleUnitCost,
      'line_subtotal': quoteItem['line_subtotal'],
      'warranty_months': warrantyMonths,
      'warranty_expiry': warrantyExpiry,
      'returned_quantity': 0.0,
      'track_serials': tracksSerials ? 1 : 0,
      'created_at': completedAt.toIso8601String(),
    });

    final changed = await txn.rawUpdate('''
      UPDATE products
      SET stock = stock - ?, updated_at = ?
      WHERE id = ? AND stock >= ?
    ''', [quantity, completedAt.toIso8601String(), productId, quantity]);
    if (changed != 1) {
      throw ComputerSalesException(
        'Stock changed while processing ${quoteItem['product_name']}. Try again.',
      );
    }

    if (tracksSerials) {
      for (final serial in serials) {
        final serialId = serial['id'] as String;
        await txn.insert('computer_document_item_serials', {
          'document_item_id': saleItemId,
          'serial_id': serialId,
        });
        final updated = await txn.update(
          'product_serials',
          {
            'status': 'sold',
            'sale_id': saleId,
            'customer_id': customerId,
            'warranty_expiry': warrantyExpiry,
            'updated_at': completedAt.toIso8601String(),
          },
          where: "id = ? AND product_id = ? AND status = 'in_stock'",
          whereArgs: [serialId, productId],
        );
        if (updated != 1) {
          throw ComputerSalesException(
            'Serial ${serial['serial_number']} is no longer available.',
          );
        }
        await _insertStockMovement(
          txn,
          productId: productId,
          serialId: serialId,
          type: 'computer_sale',
          quantity: -1,
          unitCost: (serial['purchase_cost'] as num?)?.toDouble() ??
              currentProductCost,
          referenceType: 'computer_sale',
          referenceId: saleId,
          notes: 'Converted from quotation $quotationId',
          userId: createdBy,
          createdAt: completedAt,
        );
      }
    } else {
      await _insertStockMovement(
        txn,
        productId: productId,
        type: 'computer_sale',
        quantity: -quantity,
        unitCost: currentProductCost,
        referenceType: 'computer_sale',
        referenceId: saleId,
        notes: 'Converted from quotation $quotationId',
        userId: createdBy,
        createdAt: completedAt,
      );
    }
  }

  Future<List<Map<String, Object?>>> _selectSerials(
    Transaction txn, {
    required String quoteItemId,
    required String productId,
    required double quantity,
    required String quotationId,
  }) async {
    if (!_isWhole(quantity)) {
      throw const ComputerSalesException(
        'Serialized products must use a whole-number quantity.',
      );
    }
    final requiredCount = quantity.toInt();
    final selected = await txn.rawQuery('''
      SELECT s.id, s.product_id, s.serial_number, s.purchase_cost
      FROM computer_document_item_serials dis
      INNER JOIN product_serials s ON s.id = dis.serial_id
      WHERE dis.document_item_id = ?
    ''', [quoteItemId]);
    if (selected.isNotEmpty) {
      if (selected.length != requiredCount) {
        throw const ComputerSalesException(
          'Selected serial numbers must match the product quantity.',
        );
      }
      for (final serial in selected) {
        if (serial['product_id'] != productId) {
          throw const ComputerSalesException(
            'A selected serial number belongs to another product.',
          );
        }
        final available = await txn.query(
          'product_serials',
          columns: ['id'],
          where: "id = ? AND status = 'in_stock'",
          whereArgs: [serial['id']],
          limit: 1,
        );
        if (available.isEmpty) {
          throw ComputerSalesException(
            'Serial ${serial['serial_number']} is no longer available.',
          );
        }
        if (await _isSerialReserved(
          txn,
          serial['id'] as String,
          exceptQuotationId: quotationId,
        )) {
          throw ComputerSalesException(
            'Serial ${serial['serial_number']} is reserved by another active '
            'quotation.',
          );
        }
      }
      return selected;
    }
    final automatic = await txn.rawQuery('''
      SELECT s.id, s.product_id, s.serial_number, s.purchase_cost
      FROM product_serials s
      WHERE s.product_id = ? AND s.status = 'in_stock'
        AND NOT EXISTS (
          SELECT 1
          FROM computer_document_item_serials reserved
          INNER JOIN computer_document_items i
            ON i.id = reserved.document_item_id
          INNER JOIN computer_documents d ON d.id = i.document_id
          WHERE reserved.serial_id = s.id
            AND d.document_type = 'quotation'
            AND d.status = 'draft'
            AND (d.expiry_date IS NULL OR
              julianday(d.expiry_date) >= julianday(?))
            AND d.id <> ?
        )
      ORDER BY s.created_at, s.serial_number
      LIMIT ?
    ''', [
      productId,
      DateTime.now().toIso8601String(),
      quotationId,
      requiredCount,
    ]);
    if (automatic.length != requiredCount) {
      throw const ComputerSalesException(
        'There are not enough available serial numbers for this product.',
      );
    }
    return automatic;
  }

  Future<_PreparedReturnLine> _prepareReturnLine(
    Transaction txn, {
    required String saleId,
    required ReturnLineInput input,
    required double allocationFactor,
  }) async {
    if (!input.quantity.isFinite || input.quantity <= 0) {
      throw const ComputerSalesException(
        'Return quantities must be positive.',
      );
    }
    final rows = await txn.query(
      'computer_document_items',
      where: 'id = ? AND document_id = ?',
      whereArgs: [input.saleItemId, saleId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const ComputerSalesException(
        'A selected product does not belong to this sale.',
      );
    }
    final item = rows.single;
    final soldQuantity = (item['quantity'] as num).toDouble();
    final alreadyReturned = (item['returned_quantity'] as num).toDouble();
    if (input.quantity > soldQuantity - alreadyReturned + _moneyTolerance) {
      throw ComputerSalesException(
        'Return quantity for ${item['product_name']} is greater than the '
        'remaining sold quantity.',
      );
    }

    final tracksSerials = (item['track_serials'] as num?)?.toInt() == 1;
    final serialIds = input.serialIds.toSet().toList(growable: false);
    if (tracksSerials) {
      if (!_isWhole(input.quantity) ||
          serialIds.length != input.quantity.toInt()) {
        throw ComputerSalesException(
          'Select one serial number for each returned ${item['product_name']}.',
        );
      }
      for (final serialId in serialIds) {
        final serialRows = await txn.rawQuery('''
          SELECT s.id, s.serial_number
          FROM computer_document_item_serials dis
          INNER JOIN product_serials s ON s.id = dis.serial_id
          WHERE dis.document_item_id = ? AND s.id = ?
            AND s.status = 'sold' AND s.sale_id = ?
          LIMIT 1
        ''', [input.saleItemId, serialId, saleId]);
        if (serialRows.isEmpty) {
          throw const ComputerSalesException(
            'A serial number is not available for return.',
          );
        }
      }
    } else if (serialIds.isNotEmpty) {
      throw const ComputerSalesException(
        'Serial numbers cannot be assigned to a non-serialized product.',
      );
    }
    final unitPrice = (item['unit_price'] as num).toDouble();
    return _PreparedReturnLine(
      item: item,
      quantity: input.quantity,
      serialIds: serialIds,
      refundAmount: _money(input.quantity * unitPrice * allocationFactor),
    );
  }

  Future<void> _applyReturnLine(
    Transaction txn, {
    required String returnId,
    required _PreparedReturnLine line,
    required DateTime createdAt,
    String? createdBy,
  }) async {
    final item = line.item;
    final productId = item['product_id'] as String;
    final tracksSerials = (item['track_serials'] as num?)?.toInt() == 1;
    final unitRefund =
        line.quantity <= 0 ? 0 : line.refundAmount / line.quantity;
    if (tracksSerials) {
      for (var index = 0; index < line.serialIds.length; index++) {
        final serialId = line.serialIds[index];
        final itemRefund = index == line.serialIds.length - 1
            ? _money(
                line.refundAmount -
                    _money(unitRefund) * (line.serialIds.length - 1),
              )
            : _money(unitRefund);
        await txn.insert('computer_return_items', {
          'id': _uuid.v4(),
          'return_id': returnId,
          'sale_item_id': item['id'],
          'product_id': productId,
          'quantity': 1.0,
          'serial_id': serialId,
          'refund_amount': itemRefund,
        });
        final serialRows = await txn.query(
          'product_serials',
          columns: ['purchase_cost'],
          where: "id = ? AND product_id = ? AND status = 'sold'",
          whereArgs: [serialId, productId],
          limit: 1,
        );
        if (serialRows.isEmpty) {
          throw const ComputerSalesException(
            'A serial number was already returned or changed.',
          );
        }
        final serialPurchaseCost =
            (serialRows.single['purchase_cost'] as num).toDouble();
        final changed = await txn.update(
          'product_serials',
          {
            'status': 'in_stock',
            'sale_id': null,
            'customer_id': null,
            'warranty_expiry': null,
            'updated_at': createdAt.toIso8601String(),
          },
          where: "id = ? AND status = 'sold'",
          whereArgs: [serialId],
        );
        if (changed != 1) {
          throw const ComputerSalesException(
            'A serial number was already returned or changed.',
          );
        }
        await _insertStockMovement(
          txn,
          productId: productId,
          serialId: serialId,
          type: 'computer_return',
          quantity: 1,
          unitCost: serialPurchaseCost,
          referenceType: 'computer_return',
          referenceId: returnId,
          notes: 'Serialized product returned',
          userId: createdBy,
          createdAt: createdAt,
        );
      }
    } else {
      await txn.insert('computer_return_items', {
        'id': _uuid.v4(),
        'return_id': returnId,
        'sale_item_id': item['id'],
        'product_id': productId,
        'quantity': line.quantity,
        'refund_amount': line.refundAmount,
      });
      await _insertStockMovement(
        txn,
        productId: productId,
        type: 'computer_return',
        quantity: line.quantity,
        unitCost: (item['unit_cost'] as num).toDouble(),
        referenceType: 'computer_return',
        referenceId: returnId,
        notes: 'Product returned',
        userId: createdBy,
        createdAt: createdAt,
      );
    }
    await txn.rawUpdate('''
      UPDATE products
      SET stock = stock + ?, updated_at = ?
      WHERE id = ?
    ''', [line.quantity, createdAt.toIso8601String(), productId]);
    final itemUpdated = await txn.rawUpdate('''
      UPDATE computer_document_items
      SET returned_quantity = returned_quantity + ?
      WHERE id = ? AND returned_quantity + ? <= quantity
    ''', [line.quantity, item['id'], line.quantity]);
    if (itemUpdated != 1) {
      throw const ComputerSalesException(
        'The return quantity changed while processing. Try again.',
      );
    }
  }

  Future<Map<String, Map<String, Object?>>> _validateAndLoadProducts(
    DatabaseExecutor txn,
    List<QuotationLineInput> lines, {
    String? forQuotationId,
  }) async {
    final uniqueProductIds = lines.map((line) => line.productId).toSet();
    if (uniqueProductIds.length != lines.length) {
      throw const ComputerSalesException(
        'Combine duplicate products into one quotation line.',
      );
    }
    final products = <String, Map<String, Object?>>{};
    for (final line in lines) {
      if (!line.quantity.isFinite || line.quantity <= 0) {
        throw const ComputerSalesException(
          'Product quantities must be positive.',
        );
      }
      if (!line.unitPrice.isFinite || line.unitPrice < 0) {
        throw const ComputerSalesException(
            'Product prices cannot be negative.');
      }
      if (line.warrantyMonths != null && line.warrantyMonths! < 0) {
        throw const ComputerSalesException(
          'Warranty months cannot be negative.',
        );
      }
      final rows = await txn.query(
        'products',
        where: 'id = ? AND is_active = 1',
        whereArgs: [line.productId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const ComputerSalesException(
          'A selected product is no longer available.',
        );
      }
      final product = rows.single;
      final tracksSerials = (product['track_serials'] as num?)?.toInt() == 1;
      if (tracksSerials && !_isWhole(line.quantity)) {
        throw const ComputerSalesException(
          'Serialized products must use a whole-number quantity.',
        );
      }
      final serialIds = line.serialIds.toSet();
      if (serialIds.length != line.serialIds.length) {
        throw const ComputerSalesException(
          'A serial number cannot be selected more than once.',
        );
      }
      if (!tracksSerials && serialIds.isNotEmpty) {
        throw const ComputerSalesException(
          'Serial numbers cannot be assigned to a non-serialized product.',
        );
      }
      if (tracksSerials &&
          serialIds.isNotEmpty &&
          serialIds.length != line.quantity.toInt()) {
        throw const ComputerSalesException(
          'Select all serial numbers or leave selection automatic.',
        );
      }
      for (final serialId in serialIds) {
        final serial = await txn.query(
          'product_serials',
          columns: ['id'],
          where: "id = ? AND product_id = ? AND status = 'in_stock'",
          whereArgs: [serialId, line.productId],
          limit: 1,
        );
        if (serial.isEmpty) {
          throw const ComputerSalesException(
            'A selected serial number is no longer available.',
          );
        }
        if (await _isSerialReserved(
          txn,
          serialId,
          exceptQuotationId: forQuotationId,
        )) {
          throw const ComputerSalesException(
            'A selected serial number is reserved by another active quotation.',
          );
        }
      }
      products[line.productId] = product;
    }
    return products;
  }

  _DocumentTotals _calculateTotals(
    DraftQuotationInput input,
    Map<String, Map<String, Object?>> products,
  ) {
    final subtotal = _money(input.lines.fold<double>(
      0,
      (sum, line) => sum + line.quantity * line.unitPrice,
    ));
    if (input.discountAmount > subtotal + _moneyTolerance) {
      throw const ComputerSalesException(
        'Discount cannot be greater than the subtotal.',
      );
    }
    final taxable = (subtotal - input.discountAmount).clamp(0, subtotal);
    final tax = _money(taxable * input.taxRate / 100);
    return _DocumentTotals(
      subtotal: subtotal,
      tax: tax,
      total: _money(taxable + tax),
    );
  }

  void _validateQuotationInput(DraftQuotationInput input) {
    if (input.customerId.trim().isEmpty) {
      throw const ComputerSalesException('Select a customer.');
    }
    if (input.lines.isEmpty) {
      throw const ComputerSalesException(
        'Add at least one product to the quotation.',
      );
    }
    if (!input.discountAmount.isFinite || input.discountAmount < 0) {
      throw const ComputerSalesException('Discount cannot be negative.');
    }
    if (!input.taxRate.isFinite || input.taxRate < 0 || input.taxRate > 100) {
      throw const ComputerSalesException('Tax rate must be between 0 and 100.');
    }
  }

  Future<void> _ensureCustomerExists(
    DatabaseExecutor txn,
    String customerId,
  ) async {
    final rows = await txn.query(
      'customers',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const ComputerSalesException('Selected customer was not found.');
    }
  }

  Future<Map<String, Object?>> _getDocumentRow(
    DatabaseExecutor txn,
    String id,
  ) async {
    final rows = await txn.query(
      'computer_documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const ComputerSalesException('Document was not found.');
    }
    return rows.single;
  }

  void _ensureDraftQuotation(Map<String, Object?> row) {
    if (row['document_type'] != ComputerDocumentType.quotation.dbValue ||
        row['status'] != ComputerDocumentStatus.draft.dbValue) {
      throw const ComputerSalesException(
        'Only a draft quotation can be changed or converted.',
      );
    }
  }

  void _ensureReturnableSale(Map<String, Object?> row) {
    final status = row['status'] as String?;
    if (row['document_type'] != ComputerDocumentType.sale.dbValue ||
        !{
          ComputerDocumentStatus.completed.dbValue,
          ComputerDocumentStatus.partiallyReturned.dbValue,
        }.contains(status)) {
      throw const ComputerSalesException(
        'This sale cannot accept payments or returns.',
      );
    }
  }

  Future<void> _insertPayment(
    DatabaseExecutor txn,
    String documentId,
    PaymentInput input,
    DateTime createdAt,
  ) async {
    await txn.insert('computer_payments', {
      'id': _uuid.v4(),
      'document_id': documentId,
      'amount': _normalizedPaymentAmount(input.amount, 'Payment'),
      'method': input.method.dbValue,
      'reference_number': _clean(input.referenceNumber),
      'notes': _clean(input.notes),
      'received_by': input.receivedBy,
      'created_at': createdAt.toIso8601String(),
    });
  }

  Future<void> _insertStockMovement(
    DatabaseExecutor txn, {
    required String productId,
    required String type,
    required double quantity,
    required double unitCost,
    required String referenceType,
    required String referenceId,
    required DateTime createdAt,
    String? serialId,
    String? notes,
    String? userId,
  }) async {
    await txn.insert('stock_movements', {
      'id': _uuid.v4(),
      'product_id': productId,
      'serial_id': serialId,
      'movement_type': type,
      'quantity': quantity,
      'unit_cost': unitCost,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'notes': notes,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    });
  }

  Future<String> _nextDocumentNumber(
    DatabaseExecutor txn,
    String series,
    DateTime now,
  ) async {
    final period = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    await txn.insert(
      'computer_document_counters',
      {'series': series, 'period': period, 'last_number': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await txn.rawUpdate('''
      UPDATE computer_document_counters
      SET last_number = last_number + 1
      WHERE series = ? AND period = ?
    ''', [series, period]);
    final rows = await txn.query(
      'computer_document_counters',
      columns: ['last_number'],
      where: 'series = ? AND period = ?',
      whereArgs: [series, period],
      limit: 1,
    );
    final next = (rows.single['last_number'] as num).toInt();
    return '$series-$period-${next.toString().padLeft(6, '0')}';
  }

  double _validatePayments(
    List<PaymentInput> payments, {
    double? maximum,
    String noun = 'Payment',
  }) {
    var totalCents = 0;
    for (final payment in payments) {
      final amount = _normalizedPaymentAmount(payment.amount, noun);
      totalCents += _moneyCents(amount);
    }
    final maximumCents = maximum == null ? null : _moneyCents(maximum);
    if (maximumCents != null && totalCents > maximumCents) {
      throw ComputerSalesException(
        '$noun total cannot be greater than ${maximum!.toStringAsFixed(2)}.',
      );
    }
    return totalCents / 100;
  }

  double _normalizedPaymentAmount(double amount, String noun) {
    if (!amount.isFinite || amount <= 0) {
      throw ComputerSalesException('$noun amounts must be positive.');
    }
    final normalized = _money(amount);
    if (normalized <= 0) {
      throw ComputerSalesException(
        '$noun amounts must be at least 0.01.',
      );
    }
    return normalized;
  }

  ComputerPaymentStatus _derivePaymentStatus({
    required double netPaid,
    required double balanceDue,
    required double refunded,
    required ComputerDocumentStatus saleStatus,
  }) {
    if (refunded > _moneyTolerance) {
      if (saleStatus == ComputerDocumentStatus.returned &&
          balanceDue <= _moneyTolerance &&
          netPaid <= _moneyTolerance) {
        return ComputerPaymentStatus.refunded;
      }
      return ComputerPaymentStatus.partiallyRefunded;
    }
    if (netPaid <= _moneyTolerance) return ComputerPaymentStatus.unpaid;
    if (balanceDue <= _moneyTolerance) return ComputerPaymentStatus.paid;
    return ComputerPaymentStatus.partial;
  }

  Future<bool> _isSerialReserved(
    DatabaseExecutor txn,
    String serialId, {
    String? exceptQuotationId,
  }) async {
    final rows = await txn.rawQuery('''
      SELECT EXISTS (
        SELECT 1
        FROM computer_document_item_serials reserved
        INNER JOIN computer_document_items i
          ON i.id = reserved.document_item_id
        INNER JOIN computer_documents d ON d.id = i.document_id
        WHERE reserved.serial_id = ?
          AND d.document_type = 'quotation'
          AND d.status = 'draft'
          AND (d.expiry_date IS NULL OR
            julianday(d.expiry_date) >= julianday(?))
          ${exceptQuotationId == null ? '' : 'AND d.id <> ?'}
      ) AS is_reserved
    ''', [
      serialId,
      DateTime.now().toIso8601String(),
      if (exceptQuotationId != null) exceptQuotationId,
    ]);
    return (rows.single['is_reserved'] as num).toInt() == 1;
  }

  Future<double> _sumPayments(DatabaseExecutor txn, String saleId) async {
    final rows = await txn.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS value FROM computer_payments WHERE document_id = ?',
      [saleId],
    );
    return _money((rows.single['value'] as num).toDouble());
  }

  Future<double> _sumRefunds(DatabaseExecutor txn, String saleId) async {
    final rows = await txn.rawQuery('''
      SELECT COALESCE(SUM(f.amount), 0) AS value
      FROM computer_refunds f
      INNER JOIN computer_returns r ON r.id = f.return_id
      WHERE r.sale_id = ?
    ''', [saleId]);
    return _money((rows.single['value'] as num).toDouble());
  }

  Future<double> _sumReturnValue(
    DatabaseExecutor txn,
    String saleId,
  ) async {
    final rows = await txn.rawQuery(
      'SELECT COALESCE(SUM(refund_amount), 0) AS value FROM computer_returns WHERE sale_id = ?',
      [saleId],
    );
    return _money((rows.single['value'] as num).toDouble());
  }

  bool _sameMoney(num first, num second) =>
      _moneyCents(first) == _moneyCents(second);

  int _moneyCents(num value) => (value * 100).round();

  DateTime _addMonths(DateTime date, int months) {
    final monthIndex = date.month - 1 + months;
    final targetYear = date.year + monthIndex ~/ 12;
    final targetMonth = monthIndex % 12 + 1;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = date.day > lastDay ? lastDay : date.day;
    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  bool _isWhole(double value) => (value - value.round()).abs() < 0.000001;

  double _money(num value) => (value * 100).roundToDouble() / 100;

  String _quantityText(double value) =>
      _isWhole(value) ? value.toInt().toString() : value.toStringAsFixed(2);

  static String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() => _changes.close();
}

class _DocumentTotals {
  const _DocumentTotals({
    required this.subtotal,
    required this.tax,
    required this.total,
  });

  final double subtotal;
  final double tax;
  final double total;
}

class _PreparedReturnLine {
  const _PreparedReturnLine({
    required this.item,
    required this.quantity,
    required this.serialIds,
    required this.refundAmount,
  });

  final Map<String, Object?> item;
  final double quantity;
  final List<String> serialIds;
  final double refundAmount;
}
