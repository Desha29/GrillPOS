import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../data/menu_models.dart';
import 'cubit/menu_cubit.dart';

class MenuManagementScreen extends StatelessWidget {
  const MenuManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<MenuCubit>()..loadMenu(),
      child: const _MenuManagementView(),
    );
  }
}

class _MenuManagementView extends StatelessWidget {
  const _MenuManagementView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: ScreenHeader(
                title: 'إدارة المنيو',
                subtitle: 'إعداد قوائم الطعام والأسعار والتصنيفات',
                icon: Icons.restaurant_menu,
                trailingIcon: Icons.add,
                onTrailingPressed: () => _showAddItemDialog(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            BlocBuilder<MenuCubit, MenuState>(
              builder: (context, state) {
                return Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    children: [
                      _CategoryFilterChip(
                        text: 'الكل',
                        selected: state.selectedCategoryId == null,
                        onTap: () => context.read<MenuCubit>().selectCategory(null),
                      ),
                      ...state.categories.map(
                        (c) => _CategoryFilterChip(
                          text: c.displayName,
                          selected: state.selectedCategoryId == c.id,
                          onTap: () => context.read<MenuCubit>().selectCategory(c.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add Category button in the list
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showAddCategoryDialog(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.warmOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.warmOrange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.add, size: 18, color: AppColors.warmOrange),
                                SizedBox(width: 4),
                                Text('تصنيف', style: TextStyle(color: AppColors.warmOrange, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: BlocBuilder<MenuCubit, MenuState>(
                builder: (context, state) {
                  if (state.loading && state.categories.isEmpty && state.items.isEmpty) {
                    return Center(child: CircularProgressIndicator(color: AppColors.warmOrange));
                  }

                  if (state.items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant_menu, size: 64, color: AppColors.mutedColor.withOpacity(0.3)),
                          const SizedBox(height: AppSpacing.md),
                          Text('لا توجد أصناف في هذا التصنيف',
                              style: TextStyle(color: AppColors.creamMuted, fontSize: 16)),
                          const SizedBox(height: AppSpacing.sm),
                          Text('اضغط + لإضافة صنف جديد',
                              style: TextStyle(color: AppColors.mutedColor)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    itemCount: state.items.length,
                    itemBuilder: (_, i) {
                      final item = state.items[i];
                      return _MenuItemTile(item: item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.warmOrange,
        onPressed: () => _showAddItemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة صنف'),
      ),
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final cubit = context.read<MenuCubit>();
    final nameCtrl = TextEditingController();

    await showDialog(
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
                      'إضافة تصنيف جديد',
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
                    labelText: 'اسم التصنيف',
                    prefixIcon: Icon(Icons.category, color: AppColors.mutedColor),
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
                        if (nameCtrl.text.trim().isEmpty) return;
                        cubit.addCategory(nameCtrl.text.trim());
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('إنشاء'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warmOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Future<void> _showAddItemDialog(BuildContext context) async {
    final cubit = context.read<MenuCubit>();
    final state = cubit.state;
    if (state.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة تصنيف أولاً')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String categoryId = state.categories.first.id;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Dialog(
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
                        'إضافة صنف جديد',
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
                      labelText: 'اسم الصنف',
                      prefixIcon: Icon(Icons.fastfood, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: priceCtrl,
                    style: TextStyle(color: AppColors.cream),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'السعر',
                      prefixIcon: Icon(Icons.attach_money, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: categoryId,
                    dropdownColor: AppColors.charcoalLight,
                    style: TextStyle(color: AppColors.cream, fontSize: 16),
                    icon: Icon(Icons.arrow_drop_down, color: AppColors.cream),
                    items: state.categories
                        .map((c) => DropdownMenuItem(
                            value: c.id, child: Text(c.displayName)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => categoryId = v);
                    },
                    decoration: InputDecoration(
                      labelText: 'التصنيف',
                      prefixIcon: Icon(Icons.category, color: AppColors.mutedColor),
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
                          final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                          if (name.isEmpty || price <= 0) return;
                          
                          // Use the locally captured cubit
                          cubit.addItem(
                                name: name,
                                categoryId: categoryId,
                                price: price,
                              );
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('إنشاء'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warmOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
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
  }
}

class _MenuItemTile extends StatelessWidget {
  final MenuItem item;

  const _MenuItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          onTap: () {
            // Optional: Handle item edit if needed
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.charcoalMedium,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor),
                    image: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(item.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? null
                      : Center(
                          child: Text(
                            item.displayName.isEmpty
                                ? '?'
                                : item.displayName[0].toUpperCase(),
                            style: TextStyle(
                                color: AppColors.warmOrange,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        style: TextStyle(
                          color: AppColors.cream,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.price.toStringAsFixed(2)} ج.م',
                        style: TextStyle(
                          color: AppColors.warmOrange,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.isAvailable 
                            ? AppColors.successGreen.withOpacity(0.15) 
                            : AppColors.grillRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: item.isAvailable 
                              ? AppColors.successGreen.withOpacity(0.5) 
                              : AppColors.grillRed.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.isAvailable ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: item.isAvailable ? AppColors.successGreen : AppColors.grillRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.isAvailable ? 'متاح' : 'غير متاح',
                            style: TextStyle(
                              color: item.isAvailable ? AppColors.successGreen : AppColors.grillRed,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: item.isAvailable,
                        onChanged: (v) => context.read<MenuCubit>().toggleItemAvailability(item.id, v),
                        activeColor: AppColors.successGreen,
                        activeTrackColor: AppColors.successGreen.withOpacity(0.3),
                        inactiveThumbColor: AppColors.grillRed,
                        inactiveTrackColor: AppColors.grillRed.withOpacity(0.3),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
}

class _CategoryFilterChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(text),
        selected: selected,
        selectedColor: AppColors.warmOrange,
        backgroundColor: AppColors.surfaceDark,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
