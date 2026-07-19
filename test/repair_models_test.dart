import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/features/repairs/data/repair_models.dart';

void main() {
  test('repair statuses round-trip through database values', () {
    for (final status in RepairStatus.values) {
      expect(RepairStatusX.fromDb(status.dbValue), status);
    }
  });

  test('balance uses final cost and never becomes negative', () {
    final now = DateTime(2026, 7, 18);
    final ticket = RepairTicket(
      id: '1',
      ticketNumber: 'REP-1',
      customerId: 'customer-1',
      customerName: 'Customer',
      customerPhone: '01000000000',
      deviceType: 'Laptop',
      reportedIssue: 'No power',
      estimatedCost: 500,
      finalCost: 650,
      deposit: 200,
      createdAt: now,
      updatedAt: now,
    );

    expect(ticket.balanceDue, 450);
    expect(ticket.copyWith(deposit: 900).balanceDue, 0);
  });
}
