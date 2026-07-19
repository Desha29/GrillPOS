import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/functions/messege.dart';
import '../../auth/presentation/cubit/user_cubit.dart';
import '../data/repair_models.dart';
import 'cubit/repairs_cubit.dart';

class RepairsScreen extends StatelessWidget {
  const RepairsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RepairsCubit>()..load(),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: _RepairsView(),
      ),
    );
  }
}

class _RepairsView extends StatefulWidget {
  const _RepairsView();

  @override
  State<_RepairsView> createState() => _RepairsViewState();
}

class _RepairsViewState extends State<_RepairsView> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => context.read<RepairsCubit>().load(search: value),
    );
  }

  Future<void> _createTicket() async {
    final input = await showDialog<NewRepairTicketInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _NewRepairDialog(),
    );
    if (input == null || !mounted) return;
    final ticket = await context.read<RepairsCubit>().create(input);
    if (!mounted) return;
    if (ticket == null) {
      MotionSnackBarError(context, 'تعذر إنشاء تذكرة الصيانة.');
    } else {
      MotionSnackBarSuccess(
          context, 'تم إنشاء التذكرة ${ticket.ticketNumber} بنجاح.');
    }
  }

  Future<void> _editTicket(RepairTicket ticket) async {
    final updated = await showDialog<RepairTicket>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RepairDetailsDialog(ticket: ticket),
    );
    if (updated == null || !mounted) return;
    final success = await context.read<RepairsCubit>().update(
          updated,
          changedBy: getIt<UserCubit>().currentUser.username,
        );
    if (!mounted) return;
    if (success) {
      MotionSnackBarSuccess(context, 'تم تحديث تذكرة الصيانة.');
    } else {
      MotionSnackBarError(context, 'تعذر تحديث تذكرة الصيانة.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RepairsCubit, RepairsState>(
      builder: (context, state) {
        return ColoredBox(
          color: AppColors.backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(onCreate: _createTicket),
                const SizedBox(height: 20),
                _Stats(stats: state.stats),
                const SizedBox(height: 20),
                _Filters(
                  controller: _searchController,
                  selectedStatus: state.status,
                  onSearch: _search,
                  onStatus: (status) => context
                      .read<RepairsCubit>()
                      .load(status: status, all: status == null),
                  onRefresh: () => context.read<RepairsCubit>().load(),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: state.error!),
                ],
                const SizedBox(height: 14),
                Expanded(
                  child: state.loading && state.tickets.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : state.tickets.isEmpty
                          ? _EmptyState(onCreate: _createTicket)
                          : RefreshIndicator(
                              onRefresh: () =>
                                  context.read<RepairsCubit>().load(),
                              child: ListView.separated(
                                itemCount: state.tickets.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, index) => _TicketCard(
                                  ticket: state.tickets[index],
                                  onTap: () =>
                                      _editTicket(state.tickets[index]),
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.orangeGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(LucideIcons.monitorCog, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Computer Service Center',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('Customers, devices, repairs, costs and delivery tracking',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('New repair ticket'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.warmOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});
  final RepairStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Open repairs',
        stats.open.toString(),
        LucideIcons.wrench,
        AppColors.blueMuted
      ),
      (
        'Ready for pickup',
        stats.ready.toString(),
        LucideIcons.circleCheckBig,
        AppColors.successGreen
      ),
      (
        'Urgent',
        stats.urgent.toString(),
        LucideIcons.triangleAlert,
        AppColors.ember
      ),
      (
        'Outstanding',
        _money(stats.totalBalanceDue),
        LucideIcons.walletCards,
        AppColors.warmOrange
      ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth < 720
          ? (constraints.maxWidth - 12) / 2
          : (constraints.maxWidth - 36) / 4;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items
            .map((item) => SizedBox(
                  width: width,
                  child: _StatCard(
                    label: item.$1,
                    value: item.$2,
                    icon: item.$3,
                    color: item.$4,
                  ),
                ))
            .toList(),
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.controller,
    required this.selectedStatus,
    required this.onSearch,
    required this.onStatus,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final RepairStatus? selectedStatus;
  final ValueChanged<String> onSearch;
  final ValueChanged<RepairStatus?> onStatus;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 700;
      final search = TextField(
        controller: controller,
        onChanged: onSearch,
        style: TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search ticket, customer, phone, serial or device...',
          prefixIcon: const Icon(LucideIcons.search, size: 19),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    onSearch('');
                  },
                  icon: const Icon(LucideIcons.x, size: 18),
                ),
          filled: true,
          fillColor: AppColors.surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderColor),
          ),
        ),
      );
      final status = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<RepairStatus?>(
            value: selectedStatus,
            dropdownColor: AppColors.surfaceColor,
            iconEnabledColor: AppColors.textSecondary,
            style: TextStyle(color: AppColors.textPrimary),
            items: [
              const DropdownMenuItem<RepairStatus?>(
                  value: null, child: Text('All statuses')),
              ...RepairStatus.values.map((value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.label),
                  )),
            ],
            onChanged: onStatus,
          ),
        ),
      );
      if (narrow) {
        return Column(children: [
          search,
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: status),
            const SizedBox(width: 10),
            IconButton.filledTonal(
                onPressed: onRefresh, icon: const Icon(LucideIcons.refreshCw)),
          ]),
        ]);
      }
      return Row(children: [
        Expanded(child: search),
        const SizedBox(width: 12),
        SizedBox(width: 190, child: status),
        const SizedBox(width: 8),
        IconButton.filledTonal(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(LucideIcons.refreshCw)),
      ]);
    });
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});
  final RepairTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(ticket.status);
    return Material(
      color: AppColors.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: ticket.priority == RepairPriority.urgent
                    ? AppColors.ember.withValues(alpha: .7)
                    : AppColors.borderColor),
          ),
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(ticket.ticketNumber,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800)),
                  if (ticket.priority == RepairPriority.urgent) ...[
                    const SizedBox(width: 8),
                    const _Pill(label: 'URGENT', color: AppColors.ember),
                  ],
                ]),
                const SizedBox(height: 6),
                Text(ticket.deviceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text('${ticket.customerName} • ${ticket.customerPhone}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 5),
                Text(ticket.reportedIssue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            );
            final trailing = Column(
              crossAxisAlignment:
                  compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                _Pill(label: ticket.status.label, color: color),
                const SizedBox(height: 10),
                Text('Balance ${_money(ticket.balanceDue)}',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(DateFormat('dd MMM yyyy, HH:mm').format(ticket.updatedAt),
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 12), trailing],
              );
            }
            return Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(LucideIcons.laptop, color: color, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(child: details),
              const SizedBox(width: 18),
              trailing,
              const SizedBox(width: 10),
              Icon(LucideIcons.chevronRight,
                  color: AppColors.textSecondary, size: 18),
            ]);
          }),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

class _NewRepairDialog extends StatefulWidget {
  const _NewRepairDialog();

  @override
  State<_NewRepairDialog> createState() => _NewRepairDialogState();
}

class _NewRepairDialogState extends State<_NewRepairDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _deviceType = TextEditingController(text: 'Laptop');
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _serial = TextEditingController();
  final _accessories = TextEditingController();
  final _issue = TextEditingController();
  final _estimate = TextEditingController();
  final _deposit = TextEditingController();
  RepairPriority _priority = RepairPriority.normal;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _email,
      _deviceType,
      _brand,
      _model,
      _serial,
      _accessories,
      _issue,
      _estimate,
      _deposit,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      NewRepairTicketInput(
        customerName: _name.text,
        customerPhone: _phone.text,
        customerEmail: _email.text,
        deviceType: _deviceType.text,
        brand: _brand.text,
        model: _model.text,
        serialNumber: _serial.text,
        accessories: _accessories.text,
        reportedIssue: _issue.text,
        priority: _priority,
        estimatedCost: _number(_estimate.text),
        deposit: _number(_deposit.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: 'New repair ticket',
      icon: LucideIcons.clipboardPlus,
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.warmOrange),
          child: const Text('Create ticket'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FormSection('Customer'),
          Row(children: [
            Expanded(child: _field(_name, 'Customer name', required: true)),
            const SizedBox(width: 12),
            Expanded(child: _field(_phone, 'Phone number', required: true)),
          ]),
          const SizedBox(height: 12),
          _field(_email, 'Email (optional)'),
          const SizedBox(height: 20),
          const _FormSection('Device'),
          Row(children: [
            Expanded(child: _field(_deviceType, 'Device type', required: true)),
            const SizedBox(width: 12),
            Expanded(child: _field(_brand, 'Brand')),
            const SizedBox(width: 12),
            Expanded(child: _field(_model, 'Model')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(_serial, 'Serial number / IMEI')),
            const SizedBox(width: 12),
            Expanded(child: _field(_accessories, 'Accessories received')),
          ]),
          const SizedBox(height: 20),
          const _FormSection('Repair and payment'),
          _field(_issue, 'Reported issue', required: true, lines: 3),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _moneyField(_estimate, 'Estimated cost')),
            const SizedBox(width: 12),
            Expanded(child: _moneyField(_deposit, 'Deposit')),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<RepairPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: RepairPriority.values
                    .map((value) => DropdownMenuItem(
                        value: value, child: Text(value.label)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _priority = value ?? RepairPriority.normal),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _RepairDetailsDialog extends StatefulWidget {
  const _RepairDetailsDialog({required this.ticket});
  final RepairTicket ticket;

  @override
  State<_RepairDetailsDialog> createState() => _RepairDetailsDialogState();
}

class _RepairDetailsDialogState extends State<_RepairDetailsDialog> {
  late final TextEditingController _diagnosis;
  late final TextEditingController _technician;
  late final TextEditingController _estimate;
  late final TextEditingController _finalCost;
  late final TextEditingController _deposit;
  late RepairStatus _status;
  late RepairPriority _priority;

  @override
  void initState() {
    super.initState();
    final ticket = widget.ticket;
    _diagnosis = TextEditingController(text: ticket.diagnosis ?? '');
    _technician = TextEditingController(text: ticket.technicianName ?? '');
    _estimate = TextEditingController(text: _plainNumber(ticket.estimatedCost));
    _finalCost = TextEditingController(text: _plainNumber(ticket.finalCost));
    _deposit = TextEditingController(text: _plainNumber(ticket.deposit));
    _status = ticket.status;
    _priority = ticket.priority;
  }

  @override
  void dispose() {
    _diagnosis.dispose();
    _technician.dispose();
    _estimate.dispose();
    _finalCost.dispose();
    _deposit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    return _DialogShell(
      title: ticket.ticketNumber,
      subtitle: '${ticket.customerName} • ${ticket.customerPhone}',
      icon: LucideIcons.monitorCog,
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            ticket.copyWith(
              diagnosis: _diagnosis.text.trim(),
              technicianName: _technician.text.trim(),
              status: _status,
              priority: _priority,
              estimatedCost: _number(_estimate.text),
              finalCost: _number(_finalCost.text),
              deposit: _number(_deposit.text),
            ),
          ),
          style: FilledButton.styleFrom(backgroundColor: AppColors.warmOrange),
          child: const Text('Save changes'),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _FormSection('Device and issue'),
        _ReadOnlyRow(label: 'Device', value: ticket.deviceLabel),
        _ReadOnlyRow(
            label: 'Serial / IMEI',
            value: ticket.serialNumber ?? 'Not provided'),
        _ReadOnlyRow(
            label: 'Accessories', value: ticket.accessories ?? 'None recorded'),
        _ReadOnlyRow(label: 'Reported issue', value: ticket.reportedIssue),
        const SizedBox(height: 18),
        const _FormSection('Workshop progress'),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<RepairStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: RepairStatus.values
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)))
                  .toList(),
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _field(_technician, 'Assigned technician')),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<RepairPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: RepairPriority.values
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _priority = value ?? _priority),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _field(_diagnosis, 'Diagnosis and work performed', lines: 4),
        const SizedBox(height: 18),
        const _FormSection('Financials'),
        Row(children: [
          Expanded(child: _moneyField(_estimate, 'Estimated cost')),
          const SizedBox(width: 12),
          Expanded(child: _moneyField(_finalCost, 'Final cost')),
          const SizedBox(width: 12),
          Expanded(child: _moneyField(_deposit, 'Paid / deposit')),
        ]),
      ]),
    );
  }
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.child,
    required this.actions,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Dialog(
          backgroundColor: AppColors.surfaceColor,
          insetPadding: const EdgeInsets.all(24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warmOrange.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.warmOrange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x),
                  ),
                ]),
              ),
              Divider(height: 1, color: AppColors.borderColor),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: child,
                ),
              ),
              Divider(height: 1, color: AppColors.borderColor),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions
                      .expand((action) => [action, const SizedBox(width: 8)])
                      .toList()
                    ..removeLast(),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _FormSection extends StatelessWidget {
  const _FormSection(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.warmOrange,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      );
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 130,
              child: Text(label,
                  style: TextStyle(color: AppColors.textSecondary))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600))),
        ]),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.grillRed.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.grillRed.withValues(alpha: .35)),
        ),
        child: Row(children: [
          const Icon(LucideIcons.circleAlert,
              color: AppColors.grillRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppColors.grillRed))),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.monitorCog,
              size: 52, color: AppColors.textSecondary),
          const SizedBox(height: 14),
          Text('No repair tickets found',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Create the first ticket or change the current filters.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Create repair ticket'),
          ),
        ]),
      );
}

TextFormField _field(
  TextEditingController controller,
  String label, {
  bool required = false,
  int lines = 1,
}) =>
    TextFormField(
      controller: controller,
      minLines: lines,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
              ? '$label is required.'
              : null
          : null,
    );

TextFormField _moneyField(TextEditingController controller, String label) =>
    TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: 'EGP '),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        final number = double.tryParse(value.trim());
        if (number == null || number < 0) return 'Enter a valid amount.';
        return null;
      },
    );

Color _statusColor(RepairStatus status) => switch (status) {
      RepairStatus.received => AppColors.blueMuted,
      RepairStatus.diagnosing => AppColors.ember,
      RepairStatus.waitingApproval => const Color(0xFF9C6ADE),
      RepairStatus.inProgress => AppColors.warmOrange,
      RepairStatus.waitingParts => const Color(0xFF8B6F47),
      RepairStatus.ready => AppColors.successGreen,
      RepairStatus.delivered => const Color(0xFF607D8B),
      RepairStatus.cancelled => AppColors.grillRed,
    };

double _number(String value) => double.tryParse(value.trim()) ?? 0;
String _plainNumber(double value) => value == 0 ? '' : value.toStringAsFixed(2);
String _money(double value) =>
    NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2).format(value);
