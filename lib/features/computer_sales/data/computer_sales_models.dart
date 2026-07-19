import 'package:equatable/equatable.dart';

enum ComputerDocumentType { quotation, sale }

enum ComputerDocumentStatus {
  draft,
  converted,
  cancelled,
  completed,
  partiallyReturned,
  returned,
}

enum ComputerPaymentStatus {
  unpaid,
  partial,
  paid,
  partiallyRefunded,
  refunded,
}

enum ComputerPaymentMethod { cash, card, bankTransfer, mobileWallet, other }

extension ComputerDocumentTypeX on ComputerDocumentType {
  String get dbValue => name;

  String get label => switch (this) {
        ComputerDocumentType.quotation => 'Quotation',
        ComputerDocumentType.sale => 'Sale',
      };

  static ComputerDocumentType fromDb(String? value) => value == 'sale'
      ? ComputerDocumentType.sale
      : ComputerDocumentType.quotation;
}

extension ComputerDocumentStatusX on ComputerDocumentStatus {
  String get dbValue => switch (this) {
        ComputerDocumentStatus.partiallyReturned => 'partially_returned',
        _ => name,
      };

  String get label => switch (this) {
        ComputerDocumentStatus.draft => 'Draft',
        ComputerDocumentStatus.converted => 'Converted',
        ComputerDocumentStatus.cancelled => 'Cancelled',
        ComputerDocumentStatus.completed => 'Completed',
        ComputerDocumentStatus.partiallyReturned => 'Partially returned',
        ComputerDocumentStatus.returned => 'Returned',
      };

  static ComputerDocumentStatus fromDb(String? value) => switch (value) {
        'converted' => ComputerDocumentStatus.converted,
        'cancelled' => ComputerDocumentStatus.cancelled,
        'completed' => ComputerDocumentStatus.completed,
        'partially_returned' => ComputerDocumentStatus.partiallyReturned,
        'returned' => ComputerDocumentStatus.returned,
        _ => ComputerDocumentStatus.draft,
      };
}

extension ComputerPaymentStatusX on ComputerPaymentStatus {
  String get dbValue => switch (this) {
        ComputerPaymentStatus.partiallyRefunded => 'partially_refunded',
        _ => name,
      };

  String get label => switch (this) {
        ComputerPaymentStatus.unpaid => 'Unpaid',
        ComputerPaymentStatus.partial => 'Partially paid',
        ComputerPaymentStatus.paid => 'Paid',
        ComputerPaymentStatus.partiallyRefunded => 'Partially refunded',
        ComputerPaymentStatus.refunded => 'Refunded',
      };

  static ComputerPaymentStatus fromDb(String? value) => switch (value) {
        'partial' => ComputerPaymentStatus.partial,
        'paid' => ComputerPaymentStatus.paid,
        'partially_refunded' => ComputerPaymentStatus.partiallyRefunded,
        'refunded' => ComputerPaymentStatus.refunded,
        _ => ComputerPaymentStatus.unpaid,
      };
}

extension ComputerPaymentMethodX on ComputerPaymentMethod {
  String get dbValue => switch (this) {
        ComputerPaymentMethod.bankTransfer => 'bank_transfer',
        ComputerPaymentMethod.mobileWallet => 'mobile_wallet',
        _ => name,
      };

  String get label => switch (this) {
        ComputerPaymentMethod.cash => 'Cash',
        ComputerPaymentMethod.card => 'Card',
        ComputerPaymentMethod.bankTransfer => 'Bank transfer',
        ComputerPaymentMethod.mobileWallet => 'Mobile wallet',
        ComputerPaymentMethod.other => 'Other',
      };

  static ComputerPaymentMethod fromDb(String? value) => switch (value) {
        'card' => ComputerPaymentMethod.card,
        'bank_transfer' => ComputerPaymentMethod.bankTransfer,
        'mobile_wallet' => ComputerPaymentMethod.mobileWallet,
        'other' => ComputerPaymentMethod.other,
        _ => ComputerPaymentMethod.cash,
      };
}

class ComputerCustomer extends Equatable {
  const ComputerCustomer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.notes,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? notes;

  factory ComputerCustomer.fromMap(Map<String, dynamic> map) =>
      ComputerCustomer(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String,
        email: map['email'] as String?,
        address: map['address'] as String?,
        notes: map['notes'] as String?,
      );

  @override
  List<Object?> get props => [id, name, phone, email, address, notes];
}

class SaleableProduct extends Equatable {
  const SaleableProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.cost,
    required this.stock,
    required this.trackSerials,
    required this.warrantyMonths,
    this.sku,
    this.barcode,
    this.brand,
    this.model,
  });

  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? brand;
  final String? model;
  final double price;
  final double cost;
  final double stock;
  final bool trackSerials;
  final int warrantyMonths;

  String get description => [brand, model]
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .join(' ');

  factory SaleableProduct.fromMap(Map<String, dynamic> map) => SaleableProduct(
        id: map['id'] as String,
        name: map['name'] as String,
        sku: map['sku'] as String?,
        barcode: map['barcode'] as String?,
        brand: map['brand'] as String?,
        model: map['model'] as String?,
        price: (map['price'] as num?)?.toDouble() ?? 0,
        cost: (map['cost'] as num?)?.toDouble() ?? 0,
        stock: (map['stock'] as num?)?.toDouble() ?? 0,
        trackSerials: (map['track_serials'] as num?)?.toInt() == 1,
        warrantyMonths: (map['warranty_months'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        sku,
        price,
        cost,
        stock,
        trackSerials,
        warrantyMonths,
      ];
}

class AvailableSerial extends Equatable {
  const AvailableSerial({
    required this.id,
    required this.productId,
    required this.serialNumber,
    required this.purchaseCost,
  });

  final String id;
  final String productId;
  final String serialNumber;
  final double purchaseCost;

  factory AvailableSerial.fromMap(Map<String, dynamic> map) => AvailableSerial(
        id: map['id'] as String,
        productId: map['product_id'] as String,
        serialNumber: map['serial_number'] as String,
        purchaseCost: (map['purchase_cost'] as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object> get props => [id, productId, serialNumber, purchaseCost];
}

class ComputerDocumentLine extends Equatable {
  const ComputerDocumentLine({
    required this.id,
    required this.documentId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.lineSubtotal,
    required this.warrantyMonths,
    required this.returnedQuantity,
    required this.trackSerials,
    this.sku,
    this.warrantyExpiry,
    this.serials = const [],
  });

  final String id;
  final String documentId;
  final String productId;
  final String productName;
  final String? sku;
  final double quantity;
  final double unitPrice;
  final double unitCost;
  final double lineSubtotal;
  final int warrantyMonths;
  final DateTime? warrantyExpiry;
  final double returnedQuantity;
  final bool trackSerials;
  final List<AvailableSerial> serials;

  double get returnableQuantity => quantity - returnedQuantity;

  factory ComputerDocumentLine.fromMap(
    Map<String, dynamic> map, {
    List<AvailableSerial> serials = const [],
  }) =>
      ComputerDocumentLine(
        id: map['id'] as String,
        documentId: map['document_id'] as String,
        productId: map['product_id'] as String,
        productName: map['product_name'] as String,
        sku: map['sku'] as String?,
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0,
        lineSubtotal: (map['line_subtotal'] as num).toDouble(),
        warrantyMonths: (map['warranty_months'] as num?)?.toInt() ?? 0,
        warrantyExpiry: _dateOrNull(map['warranty_expiry']),
        returnedQuantity: (map['returned_quantity'] as num?)?.toDouble() ?? 0,
        trackSerials: (map['track_serials'] as num?)?.toInt() == 1,
        serials: serials,
      );

  @override
  List<Object?> get props => [
        id,
        productId,
        quantity,
        unitPrice,
        warrantyExpiry,
        returnedQuantity,
        serials,
      ];
}

class ComputerPayment extends Equatable {
  const ComputerPayment({
    required this.id,
    required this.documentId,
    required this.amount,
    required this.method,
    required this.createdAt,
    this.referenceNumber,
    this.notes,
    this.receivedBy,
  });

  final String id;
  final String documentId;
  final double amount;
  final ComputerPaymentMethod method;
  final String? referenceNumber;
  final String? notes;
  final String? receivedBy;
  final DateTime createdAt;

  factory ComputerPayment.fromMap(Map<String, dynamic> map) => ComputerPayment(
        id: map['id'] as String,
        documentId: map['document_id'] as String,
        amount: (map['amount'] as num).toDouble(),
        method: ComputerPaymentMethodX.fromDb(map['method'] as String?),
        referenceNumber: map['reference_number'] as String?,
        notes: map['notes'] as String?,
        receivedBy: map['received_by'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, amount, method, referenceNumber, createdAt];
}

class ComputerDocument extends Equatable {
  const ComputerDocument({
    required this.id,
    required this.documentNumber,
    required this.type,
    required this.status,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.subtotal,
    required this.discountAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.refundedAmount,
    required this.balanceDue,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
    this.sourceQuotationId,
    this.convertedSaleId,
    this.expiryDate,
    this.notes,
    this.createdBy,
    this.completedAt,
    this.lines = const [],
    this.payments = const [],
  });

  final String id;
  final String documentNumber;
  final ComputerDocumentType type;
  final ComputerDocumentStatus status;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? sourceQuotationId;
  final String? convertedSaleId;
  final double subtotal;
  final double discountAmount;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double refundedAmount;
  final double balanceDue;
  final ComputerPaymentStatus paymentStatus;
  final DateTime? expiryDate;
  final String? notes;
  final String? createdBy;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ComputerDocumentLine> lines;
  final List<ComputerPayment> payments;

  bool get isExpired =>
      type == ComputerDocumentType.quotation &&
      expiryDate != null &&
      expiryDate!.isBefore(DateTime.now());

  factory ComputerDocument.fromMap(
    Map<String, dynamic> map, {
    List<ComputerDocumentLine> lines = const [],
    List<ComputerPayment> payments = const [],
  }) =>
      ComputerDocument(
        id: map['id'] as String,
        documentNumber: map['document_number'] as String,
        type: ComputerDocumentTypeX.fromDb(map['document_type'] as String?),
        status: ComputerDocumentStatusX.fromDb(map['status'] as String?),
        customerId: map['customer_id'] as String,
        customerName: (map['customer_name'] as String?) ?? 'Unknown customer',
        customerPhone: (map['customer_phone'] as String?) ?? '',
        sourceQuotationId: map['source_quotation_id'] as String?,
        convertedSaleId: map['converted_sale_id'] as String?,
        subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
        discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
        taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0,
        taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0,
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
        paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
        refundedAmount: (map['refunded_amount'] as num?)?.toDouble() ?? 0,
        balanceDue: (map['balance_due'] as num?)?.toDouble() ?? 0,
        paymentStatus:
            ComputerPaymentStatusX.fromDb(map['payment_status'] as String?),
        expiryDate: _dateOrNull(map['expiry_date']),
        notes: map['notes'] as String?,
        createdBy: map['created_by'] as String?,
        completedAt: _dateOrNull(map['completed_at']),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        lines: lines,
        payments: payments,
      );

  @override
  List<Object?> get props => [
        id,
        documentNumber,
        status,
        totalAmount,
        paidAmount,
        refundedAmount,
        updatedAt,
        lines,
        payments,
      ];
}

class ComputerReturnLine extends Equatable {
  const ComputerReturnLine({
    required this.id,
    required this.returnId,
    required this.saleItemId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.refundAmount,
    this.serialId,
    this.serialNumber,
  });

  final String id;
  final String returnId;
  final String saleItemId;
  final String productId;
  final String productName;
  final double quantity;
  final String? serialId;
  final String? serialNumber;
  final double refundAmount;

  factory ComputerReturnLine.fromMap(Map<String, dynamic> map) =>
      ComputerReturnLine(
        id: map['id'] as String,
        returnId: map['return_id'] as String,
        saleItemId: map['sale_item_id'] as String,
        productId: map['product_id'] as String,
        productName: (map['product_name'] as String?) ?? 'Product',
        quantity: (map['quantity'] as num).toDouble(),
        serialId: map['serial_id'] as String?,
        serialNumber: map['serial_number'] as String?,
        refundAmount: (map['refund_amount'] as num).toDouble(),
      );

  @override
  List<Object?> get props =>
      [id, saleItemId, productId, quantity, serialId, refundAmount];
}

class ComputerRefund extends Equatable {
  const ComputerRefund({
    required this.id,
    required this.returnId,
    required this.amount,
    required this.method,
    required this.createdAt,
    this.referenceNumber,
    this.notes,
    this.processedBy,
  });

  final String id;
  final String returnId;
  final double amount;
  final ComputerPaymentMethod method;
  final String? referenceNumber;
  final String? notes;
  final String? processedBy;
  final DateTime createdAt;

  factory ComputerRefund.fromMap(Map<String, dynamic> map) => ComputerRefund(
        id: map['id'] as String,
        returnId: map['return_id'] as String,
        amount: (map['amount'] as num).toDouble(),
        method: ComputerPaymentMethodX.fromDb(map['method'] as String?),
        referenceNumber: map['reference_number'] as String?,
        notes: map['notes'] as String?,
        processedBy: map['processed_by'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, returnId, amount, method, createdAt];
}

class ComputerReturn extends Equatable {
  const ComputerReturn({
    required this.id,
    required this.returnNumber,
    required this.saleId,
    required this.saleNumber,
    required this.customerName,
    required this.refundAmount,
    required this.createdAt,
    this.reason,
    this.createdBy,
    this.lines = const [],
    this.refunds = const [],
  });

  final String id;
  final String returnNumber;
  final String saleId;
  final String saleNumber;
  final String customerName;
  final double refundAmount;
  final String? reason;
  final String? createdBy;
  final DateTime createdAt;
  final List<ComputerReturnLine> lines;
  final List<ComputerRefund> refunds;

  double get processedRefundAmount =>
      refunds.fold<double>(0, (sum, refund) => sum + refund.amount);

  factory ComputerReturn.fromMap(
    Map<String, dynamic> map, {
    List<ComputerReturnLine> lines = const [],
    List<ComputerRefund> refunds = const [],
  }) =>
      ComputerReturn(
        id: map['id'] as String,
        returnNumber: map['return_number'] as String,
        saleId: map['sale_id'] as String,
        saleNumber: (map['sale_number'] as String?) ?? '',
        customerName: (map['customer_name'] as String?) ?? 'Unknown customer',
        refundAmount: (map['refund_amount'] as num?)?.toDouble() ?? 0,
        reason: map['reason'] as String?,
        createdBy: map['created_by'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        lines: lines,
        refunds: refunds,
      );

  @override
  List<Object?> get props =>
      [id, returnNumber, refundAmount, createdAt, lines, refunds];
}

class ComputerSalesStats extends Equatable {
  const ComputerSalesStats({
    this.draftQuotations = 0,
    this.completedSales = 0,
    this.salesRevenue = 0,
    this.balanceDue = 0,
    this.returnedValue = 0,
  });

  final int draftQuotations;
  final int completedSales;
  final double salesRevenue;
  final double balanceDue;
  final double returnedValue;

  @override
  List<Object> get props => [
        draftQuotations,
        completedSales,
        salesRevenue,
        balanceDue,
        returnedValue,
      ];
}

class NewComputerCustomerInput {
  const NewComputerCustomerInput({
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.notes,
  });

  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? notes;
}

class QuotationLineInput {
  const QuotationLineInput({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.warrantyMonths,
    this.serialIds = const [],
  });

  final String productId;
  final double quantity;
  final double unitPrice;
  final int? warrantyMonths;
  final List<String> serialIds;
}

class DraftQuotationInput {
  const DraftQuotationInput({
    required this.customerId,
    required this.lines,
    required this.expiryDate,
    this.discountAmount = 0,
    this.taxRate = 0,
    this.notes,
    this.createdBy,
  });

  final String customerId;
  final List<QuotationLineInput> lines;
  final DateTime expiryDate;
  final double discountAmount;
  final double taxRate;
  final String? notes;
  final String? createdBy;
}

class PaymentInput {
  const PaymentInput({
    required this.amount,
    this.method = ComputerPaymentMethod.cash,
    this.referenceNumber,
    this.notes,
    this.receivedBy,
  });

  final double amount;
  final ComputerPaymentMethod method;
  final String? referenceNumber;
  final String? notes;
  final String? receivedBy;
}

class ReturnLineInput {
  const ReturnLineInput({
    required this.saleItemId,
    required this.quantity,
    this.serialIds = const [],
  });

  final String saleItemId;
  final double quantity;
  final List<String> serialIds;
}

class SaleReturnInput {
  const SaleReturnInput({
    required this.saleId,
    required this.lines,
    this.reason,
    this.refunds = const [],
    this.createdBy,
  });

  final String saleId;
  final List<ReturnLineInput> lines;
  final String? reason;
  final List<PaymentInput> refunds;
  final String? createdBy;
}

DateTime? _dateOrNull(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
