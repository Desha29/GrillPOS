import 'package:equatable/equatable.dart';

enum RepairStatus {
  received,
  diagnosing,
  waitingApproval,
  inProgress,
  waitingParts,
  ready,
  delivered,
  cancelled,
}

enum RepairPriority { normal, urgent }

extension RepairStatusX on RepairStatus {
  String get dbValue => switch (this) {
        RepairStatus.received => 'received',
        RepairStatus.diagnosing => 'diagnosing',
        RepairStatus.waitingApproval => 'waiting_approval',
        RepairStatus.inProgress => 'in_progress',
        RepairStatus.waitingParts => 'waiting_parts',
        RepairStatus.ready => 'ready',
        RepairStatus.delivered => 'delivered',
        RepairStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        RepairStatus.received => 'Received',
        RepairStatus.diagnosing => 'Diagnosing',
        RepairStatus.waitingApproval => 'Waiting approval',
        RepairStatus.inProgress => 'In progress',
        RepairStatus.waitingParts => 'Waiting for parts',
        RepairStatus.ready => 'Ready for pickup',
        RepairStatus.delivered => 'Delivered',
        RepairStatus.cancelled => 'Cancelled',
      };

  bool get isClosed =>
      this == RepairStatus.delivered || this == RepairStatus.cancelled;

  static RepairStatus fromDb(String? value) => switch (value) {
        'diagnosing' => RepairStatus.diagnosing,
        'waiting_approval' => RepairStatus.waitingApproval,
        'in_progress' => RepairStatus.inProgress,
        'waiting_parts' => RepairStatus.waitingParts,
        'ready' => RepairStatus.ready,
        'delivered' => RepairStatus.delivered,
        'cancelled' => RepairStatus.cancelled,
        _ => RepairStatus.received,
      };
}

extension RepairPriorityX on RepairPriority {
  String get dbValue => this == RepairPriority.urgent ? 'urgent' : 'normal';
  String get label => this == RepairPriority.urgent ? 'Urgent' : 'Normal';

  static RepairPriority fromDb(String? value) =>
      value == 'urgent' ? RepairPriority.urgent : RepairPriority.normal;
}

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String,
        email: map['email'] as String?,
        address: map['address'] as String?,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, name, phone, email, address, notes];
}

class RepairTicket extends Equatable {
  const RepairTicket({
    required this.id,
    required this.ticketNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deviceType,
    this.brand,
    this.model,
    this.serialNumber,
    this.accessories,
    required this.reportedIssue,
    this.diagnosis,
    this.technicianName,
    this.status = RepairStatus.received,
    this.priority = RepairPriority.normal,
    this.estimatedCost = 0,
    this.finalCost = 0,
    this.deposit = 0,
    this.dueDate,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ticketNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deviceType;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final String? accessories;
  final String reportedIssue;
  final String? diagnosis;
  final String? technicianName;
  final RepairStatus status;
  final RepairPriority priority;
  final double estimatedCost;
  final double finalCost;
  final double deposit;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get charge => finalCost > 0 ? finalCost : estimatedCost;
  double get balanceDue => (charge - deposit).clamp(0, double.infinity);
  String get deviceLabel => [brand, model, deviceType]
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .join(' ');

  factory RepairTicket.fromMap(Map<String, dynamic> map) => RepairTicket(
        id: map['id'] as String,
        ticketNumber: map['ticket_number'] as String,
        customerId: map['customer_id'] as String,
        customerName: (map['customer_name'] as String?) ?? 'Unknown customer',
        customerPhone: (map['customer_phone'] as String?) ?? '',
        deviceType: map['device_type'] as String,
        brand: map['brand'] as String?,
        model: map['model'] as String?,
        serialNumber: map['serial_number'] as String?,
        accessories: map['accessories'] as String?,
        reportedIssue: map['reported_issue'] as String,
        diagnosis: map['diagnosis'] as String?,
        technicianName: map['technician_name'] as String?,
        status: RepairStatusX.fromDb(map['status'] as String?),
        priority: RepairPriorityX.fromDb(map['priority'] as String?),
        estimatedCost: (map['estimated_cost'] as num?)?.toDouble() ?? 0,
        finalCost: (map['final_cost'] as num?)?.toDouble() ?? 0,
        deposit: (map['deposit'] as num?)?.toDouble() ?? 0,
        dueDate: _dateOrNull(map['due_date']),
        completedAt: _dateOrNull(map['completed_at']),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'ticket_number': ticketNumber,
        'customer_id': customerId,
        'device_type': deviceType,
        'brand': brand,
        'model': model,
        'serial_number': serialNumber,
        'accessories': accessories,
        'reported_issue': reportedIssue,
        'diagnosis': diagnosis,
        'technician_name': technicianName,
        'status': status.dbValue,
        'priority': priority.dbValue,
        'estimated_cost': estimatedCost,
        'final_cost': finalCost,
        'deposit': deposit,
        'due_date': dueDate?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  RepairTicket copyWith({
    String? diagnosis,
    String? technicianName,
    RepairStatus? status,
    RepairPriority? priority,
    double? estimatedCost,
    double? finalCost,
    double? deposit,
    DateTime? dueDate,
  }) =>
      RepairTicket(
        id: id,
        ticketNumber: ticketNumber,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        deviceType: deviceType,
        brand: brand,
        model: model,
        serialNumber: serialNumber,
        accessories: accessories,
        reportedIssue: reportedIssue,
        diagnosis: diagnosis ?? this.diagnosis,
        technicianName: technicianName ?? this.technicianName,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        estimatedCost: estimatedCost ?? this.estimatedCost,
        finalCost: finalCost ?? this.finalCost,
        deposit: deposit ?? this.deposit,
        dueDate: dueDate ?? this.dueDate,
        completedAt: (status ?? this.status) == RepairStatus.delivered
            ? completedAt ?? DateTime.now()
            : completedAt,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  @override
  List<Object?> get props => [
        id,
        ticketNumber,
        status,
        priority,
        estimatedCost,
        finalCost,
        deposit,
        updatedAt,
      ];
}

class NewRepairTicketInput {
  const NewRepairTicketInput({
    required this.customerName,
    required this.customerPhone,
    required this.deviceType,
    required this.reportedIssue,
    this.customerEmail,
    this.brand,
    this.model,
    this.serialNumber,
    this.accessories,
    this.priority = RepairPriority.normal,
    this.estimatedCost = 0,
    this.deposit = 0,
    this.dueDate,
  });

  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String deviceType;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final String? accessories;
  final String reportedIssue;
  final RepairPriority priority;
  final double estimatedCost;
  final double deposit;
  final DateTime? dueDate;
}

class RepairStats extends Equatable {
  const RepairStats({
    this.open = 0,
    this.ready = 0,
    this.urgent = 0,
    this.totalBalanceDue = 0,
  });

  final int open;
  final int ready;
  final int urgent;
  final double totalBalanceDue;

  @override
  List<Object> get props => [open, ready, urgent, totalBalanceDue];
}

DateTime? _dateOrNull(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
