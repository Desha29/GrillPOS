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
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    children: [
                      _CategoryFilterChip(
                        text: 'الكل',
                        selected: state.selectedCategoryId == null,
                        onTap: () =>
                            context.read<MenuCubit>().selectCategory(null),
                      ),
                      ...state.categories.map(
                        (c) => _CategoryFilterChip(
                          text: c.displayName,
                          selected: state.selectedCategoryId == c.id,
                          onTap: () =>
                              context.read<MenuCubit>().selectCategory(c.id),
                          onLongPress: () => _showEditCategoryDialog(context, c),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.warmOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.warmOrange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.add,
                                    size: 18, color: AppColors.warmOrange),
                                SizedBox(width: 4),
                                Text('تصنيف',
                                    style: TextStyle(
                                        color: AppColors.warmOrange,
                                        fontWeight: FontWeight.bold)),
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
                  if (state.loading &&
                      state.categories.isEmpty &&
                      state.items.isEmpty) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.warmOrange));
                  }

                  if (state.items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant_menu,
                              size: 64,
                              color: AppColors.mutedColor.withOpacity(0.3)),
                          const SizedBox(height: AppSpacing.md),
                          Text('لا توجد أصناف في هذا التصنيف',
                              style: TextStyle(
                                  color: AppColors.creamMuted, fontSize: 16)),
                          const SizedBox(height: AppSpacing.sm),
                          Text('اضغط + لإضافة صنف جديد',
                              style: TextStyle(color: AppColors.mutedColor)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    itemCount: state.items.length,
                    itemBuilder: (_, i) {
                      final item = state.items[i];
                      return _MenuItemTile(
                        item: item,
                        onLongPress: () => _showEditItemDialog(context, item),
                      );
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
        label: Text('إضافة صنف'),
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
                    prefixIcon:
                        Icon(Icons.category, color: AppColors.mutedColor),
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
                      child: Text('إلغاء'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;
                        cubit.addCategory(nameCtrl.text.trim());
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text('إنشاء'),
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
    final unitCtrl = TextEditingController(); // kilo, piece, etc
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
                      prefixIcon:
                          Icon(Icons.fastfood, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: priceCtrl,
                    style: TextStyle(color: AppColors.cream),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'السعر',
                      prefixIcon:
                          Icon(Icons.attach_money, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: unitCtrl,
                    style: TextStyle(color: AppColors.cream),
                    decoration: InputDecoration(
                      labelText: 'الوحدة (مثلاً: كيلو، قطعة، سيخ)',
                      prefixIcon:
                          Icon(Icons.scale, color: AppColors.mutedColor),
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
                      prefixIcon:
                          Icon(Icons.category, color: AppColors.mutedColor),
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
                        child: Text('إلغاء'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton.icon(
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          final price =
                              double.tryParse(priceCtrl.text.trim()) ?? 0;
                          if (name.isEmpty || price <= 0) return;

                          // Use the locally captured cubit
                          cubit.addItem(
                            name: name,
                            categoryId: categoryId,
                            price: price,
                            unit: unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim(),
                          );
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text('إنشاء'),
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
      ),
    );
  }

  Future<void> _showEditCategoryDialog(BuildContext context, MenuCategory category) async {
    final cubit = context.read<MenuCubit>();
    final nameCtrl = TextEditingController(text: category.name);

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
                      'تعديل التصنيف',
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
                    prefixIcon:
                        Icon(Icons.category, color: AppColors.mutedColor),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                         cubit.deleteCategory(category.id);
                         Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.grillRed,
                      ),
                      icon: const Icon(Icons.delete, size: 18),
                      label: Text('حذف'),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.creamMuted,
                          ),
                          child: Text('إلغاء'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (nameCtrl.text.trim().isEmpty) return;
                            cubit.updateCategory(category.copyWith(name: nameCtrl.text.trim()));
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: Text('حفظ'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditItemDialog(BuildContext context, MenuItem item) async {
    final cubit = context.read<MenuCubit>();
    final state = cubit.state;

    final nameCtrl = TextEditingController(text: item.name);
    final priceCtrl = TextEditingController(text: item.price.toString());
    final unitCtrl = TextEditingController(text: item.unit ?? '');
    String categoryId = item.categoryId;

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
                        'تعديل الصنف',
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
                      prefixIcon:
                          Icon(Icons.fastfood, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: priceCtrl,
                    style: TextStyle(color: AppColors.cream),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'السعر',
                      prefixIcon:
                          Icon(Icons.attach_money, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: unitCtrl,
                    style: TextStyle(color: AppColors.cream),
                    decoration: InputDecoration(
                      labelText: 'الوحدة (مثل: كيلو، قطعة)',
                      prefixIcon:
                          Icon(Icons.scale, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: state.categories.any((c) => c.id == categoryId) ? categoryId : null,
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
                      prefixIcon:
                          Icon(Icons.category, color: AppColors.mutedColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                           cubit.deleteItem(item.id);
                           Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.grillRed,
                        ),
                        icon: const Icon(Icons.delete, size: 18),
                        label: Text('حذف'),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.creamMuted,
                            ),
                            child: Text('إلغاء'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ElevatedButton.icon(
                            onPressed: () {
                              final name = nameCtrl.text.trim();
                              final price =
                                  double.tryParse(priceCtrl.text.trim()) ?? 0;
                              if (name.isEmpty || price <= 0) return;

                              cubit.updateItem(item.copyWith(
                                name: name,
                                categoryId: categoryId,
                                price: price,
                                unit: unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim(),
                              ));
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: Text('حفظ'),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemTile extends StatefulWidget {
  final MenuItem item;
  final VoidCallback? onLongPress;

  const _MenuItemTile({required this.item, this.onLongPress});

  @override
  State<_MenuItemTile> createState() => _MenuItemTileState();
}

class _MenuItemTileState extends State<_MenuItemTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onLongPress: widget.onLongPress,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? AppColors.warmOrange.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: _isHovered ? 20 : 10,
                  offset: Offset(0, _isHovered ? 6 : 4),
                )
              ],
              border: Border.all(
                color: _isHovered
                    ? AppColors.warmOrange.withOpacity(0.4)
                    : AppColors.borderColor,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Icon/Leading
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.charcoalMedium,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.item.isAvailable 
                          ? AppColors.warmOrange.withOpacity(0.2)
                          : AppColors.borderColor
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.item.displayName.isEmpty ? '?' : widget.item.displayName[0],
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: widget.item.isAvailable ? AppColors.warmOrange : AppColors.mutedColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.displayName,
                        style: TextStyle(
                          color: widget.item.isAvailable ? AppColors.cream : AppColors.creamMuted,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.item.price.toStringAsFixed(2)} ج.م${widget.item.unit != null ? " / ${widget.item.unit}" : ""}',
                        style: TextStyle(
                          color: widget.item.isAvailable ? AppColors.successGreen : AppColors.mutedColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions
                Column(
                  children: [
                    Switch(
                      value: widget.item.isAvailable,
                      onChanged: (v) => context.read<MenuCubit>().toggleItemAvailability(widget.item.id, v),
                      activeColor: AppColors.warmOrange,
                      activeTrackColor: AppColors.warmOrange.withOpacity(0.3),
                      inactiveTrackColor: AppColors.charcoalMedium,
                    ),
                    if (_isHovered)
                      Text(
                        'إضغط مطولاً للتعديل',
                        style: TextStyle(fontSize: 10, color: AppColors.mutedColor),
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
  final VoidCallback? onLongPress;

  const _CategoryFilterChip({
    required this.text,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: ChoiceChip(
          label: Text(text),
          selected: selected,
          selectedColor: AppColors.warmOrange,
          backgroundColor: AppColors.surfaceDark,
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.creamMuted,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (_) => onTap(),
        ),
      ),
    );
  }
}

