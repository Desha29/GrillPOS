import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/components/table_card.dart';
import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../data/table_models.dart';
import 'cubit/tables_cubit.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TablesCubit>()..loadTables(),
      child: Scaffold(
        backgroundColor: AppColors.charcoalDark,
        body: SafeArea(
          child: BlocBuilder<TablesCubit, TablesState>(
            builder: (context, state) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                    child: ScreenHeader(
                      title: 'إدارة الطاولات',
                      subtitle: 'متابعة حالة الطاولات وتوزيع الصالة',
                      icon: Icons.table_restaurant,
                      trailingIcon: Icons.add,
                      onTrailingPressed: () => _showAddTableDialog(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (state.loading && state.tables.isEmpty)
                    Expanded(
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.warmOrange))),
                  if (state.error != null && state.tables.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(state.error!,
                            style: TextStyle(color: AppColors.grillRed)),
                      ),
                    ),
                  if (!state.loading && state.tables.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_restaurant,
                                size: 64,
                                color: AppColors.mutedColor.withOpacity(0.3)),
                            const SizedBox(height: AppSpacing.md),
                            Text('لا توجد طاولات مضافة',
                                style: TextStyle(
                                    color: AppColors.creamMuted, fontSize: 16)),
                            const SizedBox(height: AppSpacing.sm),
                            Text('قم بإضافة طاولات لبدء العمل',
                                style: TextStyle(color: AppColors.mutedColor)),
                          ],
                        ),
                      ),
                    ),
                  if (state.tables.isNotEmpty) ...[
                    // Summary bar
                    Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatusBadge(
                              label: 'متاحة',
                              count: state.tables
                                  .where(
                                      (t) => t.status == TableStatus.available)
                                  .length,
                              color: AppColors.successGreen),
                          _StatusBadge(
                              label: 'مشغولة',
                              count: state.tables
                                  .where(
                                      (t) => t.status == TableStatus.occupied)
                                  .length,
                              color: AppColors.grillRed),
                          _StatusBadge(
                              label: 'محجوزة',
                              count: state.tables
                                  .where(
                                      (t) => t.status == TableStatus.reserved)
                                  .length,
                              color: AppColors.ember),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 1200
                              ? 6
                              : constraints.maxWidth > 900
                                  ? 6
                                  : 2;
                          return GridView.builder(
                            itemCount: state.tables.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.md,
                              childAspectRatio: 1.0,
                            ),
                            itemBuilder: (context, index) {
                              final table = state.tables[index];
                              return TableCard(
                                table: table,
                                onTap: () => _showStatusSheet(context, table),
                              );
                            },
                          );
                        }),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddTableDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '4');

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.charcoalMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: AppColors.borderColor, width: 1.5),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إضافة طاولة جديدة',
                      style: TextStyle(
                          color: AppColors.cream,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: AppColors.creamMuted),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: AppColors.cream),
                  decoration: InputDecoration(
                    labelText: 'رقم أو اسم الطاولة',
                    prefixIcon:
                        Icon(Icons.numbers, color: AppColors.mutedColor),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: capacityCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.cream),
                  decoration: InputDecoration(
                    labelText: 'سعة الطاولة (أشخاص)',
                    prefixIcon: Icon(Icons.group, color: AppColors.mutedColor),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.creamMuted,
                      ),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton.icon(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        final cap = int.tryParse(capacityCtrl.text.trim()) ?? 4;
                        context.read<TablesCubit>().addTable(
                            name.isEmpty ? null : name,
                            capacity: cap);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('حفظ الطاولة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warmOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
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

  void _showStatusSheet(BuildContext context, RestaurantTable table) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadius)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              table.displayName,
              style: TextStyle(
                color: AppColors.cream,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...TableStatus.values.map(
              (s) => ListTile(
                leading: Icon(
                  table.status == s
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: table.status == s
                      ? AppColors.warmOrange
                      : AppColors.mutedColor,
                  size: 20,
                ),
                title: Text(
                  s.displayName,
                  style: TextStyle(
                    color: table.status == s
                        ? AppColors.warmOrange
                        : AppColors.cream,
                    fontWeight:
                        table.status == s ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  context.read<TablesCubit>().changeStatus(table.id, s);
                  Navigator.of(context).pop();
                },
              ),
            ),
            Divider(color: AppColors.borderColor),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: AppColors.cream),
              title: Text(
                'تعديل الطاولة',
                style: TextStyle(
                    color: AppColors.cream, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditTableDialog(context, table);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.grillRed),
              title: Text(
                'حذف الطاولة',
                style: TextStyle(
                    color: AppColors.grillRed, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteTable(context, table);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTableDialog(BuildContext context, RestaurantTable table) {
    final nameCtrl =
        TextEditingController(text: table.name ?? table.tableNumber.toString());
    final capacityCtrl = TextEditingController(text: table.capacity.toString());

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.charcoalMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: AppColors.borderColor, width: 1.5),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تعديل الطاولة',
                      style: TextStyle(
                          color: AppColors.cream,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: AppColors.creamMuted),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: AppColors.cream),
                  decoration: InputDecoration(
                    labelText: 'رقم أو اسم الطاولة',
                    prefixIcon:
                        Icon(Icons.numbers, color: AppColors.mutedColor),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: capacityCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.cream),
                  decoration: InputDecoration(
                    labelText: 'سعة الطاولة (أشخاص)',
                    prefixIcon: Icon(Icons.group, color: AppColors.mutedColor),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.creamMuted),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton.icon(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        final cap = int.tryParse(capacityCtrl.text.trim()) ?? 4;
                        context.read<TablesCubit>().updateTable(table.copyWith(
                              name: name.isEmpty ? null : name,
                              capacity: cap,
                            ));
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('حفظ التعديلات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warmOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
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

  void _confirmDeleteTable(BuildContext context, RestaurantTable table) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.charcoalMedium,
        title: Text('حذف الطاولة', style: TextStyle(color: AppColors.cream)),
        content: Text('هل أنت متأكد من حذف ${table.displayName}؟',
            style: TextStyle(color: AppColors.creamMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('إلغاء', style: TextStyle(color: AppColors.mutedColor)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TablesCubit>().deleteTable(table.id);
              Navigator.pop(dialogCtx);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.grillRed),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $count',
          style: TextStyle(
            color: AppColors.creamMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
