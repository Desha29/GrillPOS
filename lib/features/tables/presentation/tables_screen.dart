import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/components/screen_header.dart';
import '../../../core/components/table_card.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/functions/messege.dart';
import '../data/table_models.dart';
import '../data/tables_repository.dart';
import 'cubit/tables_cubit.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TablesCubit>()..loadTables(),
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: _TablesView(),
      ),
    );
  }
}

class _TablesView extends StatefulWidget {
  const _TablesView();

  @override
  State<_TablesView> createState() => _TablesViewState();
}

class _TablesViewState extends State<_TablesView> {
  final _searchController = TextEditingController();
  StreamSubscription<void>? _changes;
  String _query = '';
  String? _sectionFilter;
  TableStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _changes = getIt<TablesRepository>().tablesStream.listen((_) {
      if (mounted) context.read<TablesCubit>().loadTables();
    });
  }

  @override
  void dispose() {
    _changes?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<RestaurantTable> _filtered(List<RestaurantTable> tables) {
    final query = _query.trim().toLowerCase();
    return tables.where((table) {
      if (_statusFilter != null && table.status != _statusFilter) return false;
      if (_sectionFilter != null && table.section != _sectionFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return table.displayName.toLowerCase().contains(query) ||
          table.tableNumber.toString().contains(query) ||
          table.section.toLowerCase().contains(query) ||
          (table.currentOrderId?.toLowerCase().contains(query) ?? false);
    }).toList(growable: false);
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _sectionFilter = null;
      _statusFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: BlocListener<TablesCubit, TablesState>(
          listenWhen: (previous, current) =>
              previous.error != current.error ||
              previous.notice != current.notice,
          listener: (context, state) {
            if (state.error != null) {
              MotionSnackBarError(context, state.error!);
            } else if (state.notice != null) {
              MotionSnackBarSuccess(context, state.notice!);
            }
          },
          child: BlocBuilder<TablesCubit, TablesState>(
            builder: (context, state) {
              final tables = state.tables;
              final visible = _filtered(tables);
              final sections = tables
                  .map((table) => table.section)
                  .toSet()
                  .toList(growable: false)
                ..sort();
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScreenHeader(
                      title: 'إدارة صالة المطعم',
                      subtitle:
                          'حالة الطاولات، الأقسام، السعة والطلبات النشطة لحظة بلحظة',
                      icon: LucideIcons.armchair,
                      trailingIcon: LucideIcons.plus,
                      onTrailingPressed: () => _showTableEditor(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _TableStats(tables: tables),
                    const SizedBox(height: AppSpacing.md),
                    _TablesToolbar(
                      searchController: _searchController,
                      status: _statusFilter,
                      section: _sectionFilter,
                      sections: sections,
                      onSearch: (value) => setState(() => _query = value),
                      onStatus: (value) =>
                          setState(() => _statusFilter = value),
                      onSection: (value) =>
                          setState(() => _sectionFilter = value),
                      onRefresh: context.read<TablesCubit>().loadTables,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: Stack(
                        children: [
                          if (state.loading && tables.isEmpty)
                            const _TablesLoading()
                          else if (state.error != null && tables.isEmpty)
                            _TablesError(
                              message: state.error!,
                              onRetry: context.read<TablesCubit>().loadTables,
                            )
                          else if (tables.isEmpty)
                            _TablesEmpty(
                              filtered: false,
                              onAction: () => _showTableEditor(context),
                            )
                          else if (visible.isEmpty)
                            _TablesEmpty(
                              filtered: true,
                              onAction: _resetFilters,
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 1450
                                    ? 5
                                    : constraints.maxWidth >= 1120
                                        ? 4
                                        : constraints.maxWidth >= 820
                                            ? 3
                                            : constraints.maxWidth >= 540
                                                ? 2
                                                : 1;
                                return GridView.builder(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSpacing.lg),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: AppSpacing.md,
                                    mainAxisSpacing: AppSpacing.md,
                                    mainAxisExtent: 228,
                                  ),
                                  itemCount: visible.length,
                                  itemBuilder: (context, index) {
                                    final table = visible[index];
                                    return TableCard(
                                      table: table,
                                      onTap: () =>
                                          _showTableDetails(context, table),
                                    );
                                  },
                                );
                              },
                            ),
                          if (state.saving && tables.isNotEmpty)
                            const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: LinearProgressIndicator(
                                minHeight: 2,
                                color: AppColors.warmOrange,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showTableEditor(
    BuildContext context, {
    RestaurantTable? table,
  }) async {
    final cubit = context.read<TablesCubit>();
    final nameController = TextEditingController(text: table?.name ?? '');
    final capacityController =
        TextEditingController(text: '${table?.capacity ?? 4}');
    final sectionController =
        TextEditingController(text: table?.section ?? 'الصالة الرئيسية');
    final editing = table != null;
    String? validationError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.surfaceColor,
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: AppColors.borderColor),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DialogHeader(
                    icon: editing ? LucideIcons.armchair : LucideIcons.plus,
                    title: editing
                        ? 'تعديل ${table.displayName}'
                        : 'إضافة طاولة جديدة',
                    subtitle: editing
                        ? 'حدّث اسم الطاولة وسعتها وقسم الصالة.'
                        : 'سيتم إنشاء رقم طاولة فريد تلقائياً.',
                    onClose: () => Navigator.pop(dialogContext),
                  ),
                  const SizedBox(height: 22),
                  if (editing) ...[
                    _ReadOnlyInfo(
                      icon: LucideIcons.hash,
                      label: 'رقم الطاولة الثابت',
                      value: '${table.tableNumber}',
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: nameController,
                    autofocus: !editing,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم مختصر (اختياري)',
                      hintText: 'مثال: بجوار النافذة',
                      prefixIcon: Icon(LucideIcons.tag),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: capacityController,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'عدد المقاعد',
                            prefixIcon: Icon(LucideIcons.usersRound),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: sectionController,
                          decoration: const InputDecoration(
                            labelText: 'قسم الصالة',
                            hintText: 'الصالة الرئيسية',
                            prefixIcon: Icon(LucideIcons.mapPin),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 14),
                    _InlineError(message: validationError!),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('إلغاء'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final capacity =
                              int.tryParse(capacityController.text.trim());
                          final section = sectionController.text.trim();
                          String? error;
                          if (capacity == null ||
                              capacity < 1 ||
                              capacity > 30) {
                            error = 'عدد المقاعد يجب أن يكون بين 1 و30.';
                          } else if (section.isEmpty) {
                            error = 'اكتب اسم قسم الصالة.';
                          } else if (name.length > 50 || section.length > 40) {
                            error = 'اسم الطاولة أو القسم طويل جداً.';
                          }
                          if (error != null) {
                            setDialogState(() => validationError = error);
                            return;
                          }
                          setDialogState(() => validationError = null);
                          final saved = editing
                              ? await cubit.updateTable(
                                  table.copyWith(
                                    name: name.isEmpty ? null : name,
                                    clearName: name.isEmpty,
                                    capacity: capacity,
                                    section: section,
                                  ),
                                )
                              : await cubit.addTable(
                                  name.isEmpty ? null : name,
                                  capacity: capacity!,
                                  section: section,
                                );
                          if (saved && dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.warmOrange,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(
                          editing ? LucideIcons.save : LucideIcons.plus,
                          size: 17,
                        ),
                        label:
                            Text(editing ? 'حفظ التعديلات' : 'إضافة الطاولة'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    nameController.dispose();
    capacityController.dispose();
    sectionController.dispose();
  }

  Future<void> _showTableDetails(
    BuildContext context,
    RestaurantTable table,
  ) async {
    final cubit = context.read<TablesCubit>();
    final occupied = table.currentOrderId != null;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surfaceColor,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppColors.borderColor),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 590),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DialogHeader(
                  icon: _statusIcon(table.status),
                  title: table.displayName,
                  subtitle:
                      'طاولة ${table.tableNumber} • ${table.capacity} مقاعد • ${table.section}',
                  color: _statusColor(table.status),
                  onClose: () => Navigator.pop(dialogContext),
                ),
                const SizedBox(height: 18),
                if (occupied)
                  _ActiveOrderPanel(orderId: table.currentOrderId!)
                else ...[
                  Text(
                    'تغيير الحالة التشغيلية',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      TableStatus.available,
                      TableStatus.reserved,
                      TableStatus.cleaning,
                    ].map((status) {
                      return _StatusChoice(
                        status: status,
                        selected: table.status == status,
                        onTap: () async {
                          if (table.status == status) return;
                          final saved =
                              await cubit.changeStatus(table.id, status);
                          if (saved && dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                Divider(color: AppColors.borderColor),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إغلاق'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _showTableEditor(context, table: table);
                      },
                      icon: const Icon(LucideIcons.pencil, size: 16),
                      label: const Text('تعديل البيانات'),
                    ),
                    OutlinedButton.icon(
                      onPressed: occupied
                          ? null
                          : () {
                              Navigator.pop(dialogContext);
                              _confirmDelete(context, table);
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.grillRed,
                      ),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      label: const Text('حذف'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RestaurantTable table,
  ) async {
    if (table.currentOrderId != null || table.status == TableStatus.occupied) {
      MotionSnackBarWarning(context, 'لا يمكن حذف طاولة مرتبطة بطلب نشط.');
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.borderColor),
            ),
            icon: const Icon(
              LucideIcons.trash2,
              color: AppColors.grillRed,
              size: 32,
            ),
            title: Text('حذف ${table.displayName}؟'),
            content: const Text(
              'يمكن حذف الطاولة فقط إذا لم ترتبط بأي طلب سابق. يحتفظ GrillPOS بسجل الطلبات المالي.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('عودة'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.grillRed,
                ),
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: const Text('تأكيد الحذف'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && context.mounted) {
      await context.read<TablesCubit>().deleteTable(table.id);
    }
  }
}

class _TableStats extends StatelessWidget {
  const _TableStats({required this.tables});

  final List<RestaurantTable> tables;

  @override
  Widget build(BuildContext context) {
    int count(TableStatus status) =>
        tables.where((table) => table.status == status).length;
    final seats = tables.fold<int>(0, (sum, table) => sum + table.capacity);
    final data = [
      _StatData('متاحة', '${count(TableStatus.available)}',
          LucideIcons.circleCheck, AppColors.successGreen),
      _StatData('مشغولة', '${count(TableStatus.occupied)}',
          LucideIcons.utensils, AppColors.grillRed),
      _StatData('محجوزة', '${count(TableStatus.reserved)}',
          LucideIcons.calendarClock, AppColors.warmOrange),
      _StatData('إجمالي المقاعد', '$seats', LucideIcons.usersRound,
          AppColors.blueMuted),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: data
                  .map((item) => SizedBox(
                        width: 180,
                        child: _StatCard(data: item),
                      ))
                  .expand((item) => [item, const SizedBox(width: 10)])
                  .toList(),
            ),
          );
        }
        final children = data
            .map((item) => Expanded(child: _StatCard(data: item)))
            .expand((item) => <Widget>[item, const SizedBox(width: 10)])
            .toList()
          ..removeLast();
        return Row(children: children);
      },
    );
  }
}

class _StatData {
  const _StatData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          const SizedBox(width: 11),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                data.label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TablesToolbar extends StatelessWidget {
  const _TablesToolbar({
    required this.searchController,
    required this.status,
    required this.section,
    required this.sections,
    required this.onSearch,
    required this.onStatus,
    required this.onSection,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final TableStatus? status;
  final String? section;
  final List<String> sections;
  final ValueChanged<String> onSearch;
  final ValueChanged<TableStatus?> onStatus;
  final ValueChanged<String?> onSection;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 850;
          final search = TextField(
            controller: searchController,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الرقم أو القسم أو رقم الطلب...',
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        onSearch('');
                      },
                      icon: const Icon(LucideIcons.x, size: 17),
                    ),
              isDense: true,
            ),
          );
          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<TableStatus?>(
                  value: status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الحالة',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<TableStatus?>(
                      value: null,
                      child: Text('كل الحالات'),
                    ),
                    ...TableStatus.values.map(
                      (value) => DropdownMenuItem<TableStatus?>(
                        value: value,
                        child: Text(value.displayName),
                      ),
                    ),
                  ],
                  onChanged: onStatus,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String?>(
                  value: section,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'القسم',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('كل الأقسام'),
                    ),
                    ...sections.map(
                      (value) => DropdownMenuItem<String?>(
                        value: value,
                        child: Text(value, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: onSection,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'تحديث',
                onPressed: onRefresh,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
              ),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: controls,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final TableStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: .14) : AppColors.charcoalLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_statusIcon(status), color: color, size: 16),
            const SizedBox(width: 7),
            Text(
              status.displayName,
              style: TextStyle(
                color: selected ? color : AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(LucideIcons.check, color: color, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveOrderPanel extends StatelessWidget {
  const _ActiveOrderPanel({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.grillRed.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grillRed.withValues(alpha: .26)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.receiptText,
              color: AppColors.grillRed, size: 24),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الطاولة مرتبطة بطلب نشط',
                  style: TextStyle(
                    color: AppColors.grillRed,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  orderId,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'أكمل الطلب أو ألغِه من شاشة الطلبات لتتحرر الطاولة تلقائياً.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.color = AppColors.warmOrange,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(LucideIcons.x),
        ),
      ],
    );
  }
}

class _ReadOnlyInfo extends StatelessWidget {
  const _ReadOnlyInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.warmOrange, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.grillRed.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.grillRed.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.circleAlert,
              color: AppColors.grillRed, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.grillRed,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TablesLoading extends StatelessWidget {
  const _TablesLoading();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: AppColors.warmOrange),
      );
}

class _TablesError extends StatelessWidget {
  const _TablesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.circleAlert,
              color: AppColors.grillRed, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _TablesEmpty extends StatelessWidget {
  const _TablesEmpty({required this.filtered, required this.onAction});

  final bool filtered;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtered ? LucideIcons.searchX : LucideIcons.armchair,
            color: AppColors.textSecondary.withValues(alpha: .5),
            size: 54,
          ),
          const SizedBox(height: 13),
          Text(
            filtered
                ? 'لا توجد طاولات تطابق الفلاتر'
                : 'لم تتم إضافة طاولات بعد',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filtered
                ? 'غيّر الحالة أو القسم أو عبارة البحث.'
                : 'أضف أول طاولة وحدد سعتها وقسمها.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: Icon(filtered ? LucideIcons.rotateCcw : LucideIcons.plus),
            label: Text(filtered ? 'مسح الفلاتر' : 'إضافة طاولة'),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(TableStatus status) => switch (status) {
      TableStatus.available => AppColors.successGreen,
      TableStatus.occupied => AppColors.grillRed,
      TableStatus.reserved => AppColors.warmOrange,
      TableStatus.cleaning => AppColors.blueMuted,
    };

IconData _statusIcon(TableStatus status) => switch (status) {
      TableStatus.available => LucideIcons.circleCheck,
      TableStatus.occupied => LucideIcons.utensils,
      TableStatus.reserved => LucideIcons.calendarClock,
      TableStatus.cleaning => LucideIcons.sparkles,
    };
