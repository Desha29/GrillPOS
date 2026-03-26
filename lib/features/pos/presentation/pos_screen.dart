import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/components/cart_item_widget.dart';
import '../../../core/components/screen_header.dart';
import '../../../core/components/food_card.dart';
import '../../../core/components/pos_button.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../../invoice/presentation/invoice_screen.dart';
import '../../menu/data/menu_models.dart';
import '../../orders/data/order_models.dart';
import '../../settings/presentation/cubit/settings_cubit.dart';
import '../../tables/presentation/cubit/tables_cubit.dart';
import 'cubit/pos_cubit.dart';

class POSScreen extends StatelessWidget {
  const POSScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<POSCubit>()..loadMenu()),
        BlocProvider.value(value: getIt<TablesCubit>()..loadTables()),
      ],
      child: const _POSView(),
    );
  }
}

class _POSView extends StatelessWidget {
  const _POSView();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 1100;

    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      body: BlocBuilder<POSCubit, POSState>(
        builder: (context, state) {
          if (state.loading &&
              state.categories.isEmpty &&
              state.visibleItems.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null && state.visibleItems.isEmpty) {
            return Center(
              child: Text(
                state.error!,
                style: TextStyle(color: AppColors.grillRed),
              ),
            );
          }

          if (isMobile) {
            return Column(
              children: [
                Expanded(flex: 55, child: _MenuSection(state: state)),
                Divider(height: 1, color: AppColors.borderColor),
                Expanded(flex: 45, child: _CartSection(state: state)),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 65, child: _MenuSection(state: state)),
              VerticalDivider(width: 1, color: AppColors.borderColor),
              Expanded(flex: 35, child: _CartSection(state: state)),
            ],
          );
        },
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final POSState state;

  const _MenuSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<POSCubit>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 1200 ? 6 : width > 900 ? 5 : width > 600 ? 4 : width > 400 ? 3 : 2;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: const ScreenHeader(
                title: 'نقطة البيع',
                subtitle: 'سجل الطلبات بسرعة وكفاءة',
                icon: Icons.computer,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _CategoryChip(
                      label: 'الكل',
                      selected: state.selectedCategoryId == null,
                      onTap: () => cubit.selectCategory(null),
                    ),
                    ...state.categories.map(
                      (c) => _CategoryChip(
                        label: c.displayName,
                        selected: state.selectedCategoryId == c.id,
                        onTap: () => cubit.selectCategory(c.id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: state.visibleItems.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد أصناف متاحة',
                        style: TextStyle(color: AppColors.creamMuted),
                      ),
                    )
                    : GridView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 1.6,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                        ),
                        itemCount: state.visibleItems.length,
                        itemBuilder: (_, i) {
                          final item = state.visibleItems[i];
                          return FoodCard(
                            item: item,
                            onTap: () {
                              if (item.unit == 'كيلو' || 
                                  ['cat_grills', 'cat_kebab', 'cat_kofta'].contains(item.categoryId)) {
                                _showWeightPicker(context, item);
                              } else {
                                cubit.addToCart(item);
                              }
                            },
                          );
                        },
                      ),
              ),
          ],
        );
      },
    );
  }

    void _showWeightPicker(BuildContext context, MenuItem item) {
      final cubit = context.read<POSCubit>();
      showDialog(
        context: context,
        builder: (dialogCtx) {
          double customWeight = 1.0;
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              backgroundColor: AppColors.charcoalMedium,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('تحديد الكمية - ${item.displayName}', style: TextStyle(color: AppColors.cream)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _weightButton(setState, 0.25, 'ربع كيلو', () => customWeight = 0.25),
                      _weightButton(setState, 0.5, 'نصف كيلو', () => customWeight = 0.5),
                      _weightButton(setState, 0.75, 'كيلو إلا ربع', () => customWeight = 0.75),
                      _weightButton(setState, 1.0, '1 كيلو', () => customWeight = 1.0),
                      _weightButton(setState, 1.5, '1.5 كيلو', () => customWeight = 1.5),
                      _weightButton(setState, 2.0, '2 كيلو', () => customWeight = 2.0),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: AppColors.borderColor),
                  const SizedBox(height: 10),
                  Text('كمية مخصصة', style: TextStyle(color: AppColors.creamMuted, fontSize: 13)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: AppColors.warmOrange),
                        onPressed: () => setState(() => customWeight = (customWeight - 0.05).clamp(0.05, 50.0)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: Text(
                          customWeight.toStringAsFixed(3),
                          style: TextStyle(color: AppColors.warmOrange, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: AppColors.warmOrange),
                        onPressed: () => setState(() => customWeight += 0.05),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('إلغاء', style: TextStyle(color: AppColors.mutedColor)),
                ),
                ElevatedButton(
                  onPressed: () {
                    cubit.addToCart(item, quantity: customWeight);
                    Navigator.pop(dialogCtx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmOrange),
                  child: const Text('إضافة للسلة', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      );
    }

    Widget _weightButton(StateSetter setState, double weight, String label, VoidCallback onSelect) {
      return InkWell(
        onTap: () {
          onSelect();
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.charcoalLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Text(label, style: TextStyle(color: AppColors.cream, fontSize: 13)),
        ),
      );
    }
}

class _CartSection extends StatelessWidget {
  final POSState state;

  const _CartSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<POSCubit>();

    return Container(
      color: AppColors.charcoalMedium,
      child: Column(
        children: [
          // Header - cart title + order type selector
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'سلة الطلبات',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (state.cart.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.grillRed,
                      backgroundColor: AppColors.grillRed.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => cubit.clearCart(),
                    icon: const Icon(Icons.delete_sweep, size: 16),
                    label: const Text('إفراغ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Order type segmented control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeSegmentButton(
                      label: 'داخلي',
                      icon: Icons.restaurant,
                      selected: state.orderType == OrderType.dineIn,
                      onTap: () => cubit.setOrderType(OrderType.dineIn),
                    ),
                  ),
                  Expanded(
                    child: _TypeSegmentButton(
                      label: 'تيك أواي',
                      icon: Icons.shopping_bag_outlined,
                      selected: state.orderType == OrderType.takeaway,
                      onTap: () => cubit.setOrderType(OrderType.takeaway),
                    ),
                  ),
                  Expanded(
                    child: _TypeSegmentButton(
                      label: 'توصيل',
                      icon: Icons.delivery_dining,
                      selected: state.orderType == OrderType.delivery,
                      onTap: () => cubit.setOrderType(OrderType.delivery),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Optional Table Selector for Dine-in
          if (state.orderType == OrderType.dineIn)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: InkWell(
                onTap: () => _showTableSelector(context, state),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.table_restaurant, color: AppColors.warmOrange, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: BlocBuilder<TablesCubit, TablesState>(
                          builder: (context, tablesState) {
                            String label = 'تحديد طاولة (اختياري)';
                            if (state.selectedTableId != null) {
                              try {
                                final table = tablesState.tables.firstWhere((t) => t.id == state.selectedTableId);
                                label = 'الطاولة: ${table.displayName}';
                              } catch (_) {
                                label = 'الطاولة محددة';
                              }
                            }
                            return Text(label, style: TextStyle(color: AppColors.cream, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis);
                          },
                        ),
                      ),
                      if (state.selectedTableId != null)
                        GestureDetector(
                          onTap: () => context.read<POSCubit>().selectTable(null),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(Icons.close, color: AppColors.mutedColor, size: 16),
                          ),
                        )
                      else
                        Icon(Icons.arrow_drop_down, color: AppColors.mutedColor, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          // Cart items list
          Expanded(
            child: state.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 40,
                            color: AppColors.mutedColor.withOpacity(0.4)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'السلة فارغة',
                          style: TextStyle(color: AppColors.creamMuted, fontSize: 14),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'اضغط على أي صنف لإضافته',
                          style: TextStyle(
                              color: AppColors.mutedColor, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: state.cart.length,
                    itemBuilder: (_, i) {
                      final c = state.cart[i];
                      final item = OrderItem(
                        id: c.item.id,
                        orderId: 'draft',
                        menuItemId: c.item.id,
                        itemName: c.item.displayName,
                        quantity: c.quantity,
                        unitPrice: c.item.price,
                        subtotal: c.lineTotal,
                        createdAt: DateTime.now(),
                      );

                      return CartItemWidget(
                        item: item,
                        onAdd: () {
                          final step = (item.unit == 'كيلو') ? 0.25 : 1.0;
                          cubit.updateQuantity(item.menuItemId, item.quantity + step);
                        },
                        onRemove: () {
                          final step = (item.unit == 'كيلو') ? 0.25 : 1.0;
                          cubit.updateQuantity(item.menuItemId, item.quantity - step);
                        },
                        onDelete: () => cubit.removeFromCart(item.menuItemId),
                        onAddNote: () {},
                      );
                    },
                  ),
          ),
          // Totals + Checkout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(top: BorderSide(color: AppColors.borderColor)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _amountRow(context, 'المجموع الفرعي', state.subtotal),
                  const SizedBox(height: 1),
                  _amountRow(context, 'الضريبة (${(state.taxRate * 100).toStringAsFixed(0)}%)', state.tax, isTax: true, taxRate: state.taxRate),
                  Divider(color: AppColors.borderColor, height: 12),
                  _amountRow(context, 'الإجمالي', state.total, isTotal: true),
                  const SizedBox(height: 8),
                  POSButton(
                    label: 'إتمام الطلب',
                    icon: Icons.payment,
                    width: double.infinity,
                    onPressed: state.cart.isEmpty
                        ? () {}
                        : () async {
                            final cubit = context.read<POSCubit>();
                            final order = await cubit.checkout();
                            if (!context.mounted) return;
                            
                            if (order == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(cubit.state.error ?? 'خطأ أثناء إتمام الطلب'),
                                  backgroundColor: AppColors.grillRed,
                                ),
                              );
                              return;
                            }
                            
                            final restaurantInfo =
                                getIt<SettingsCubit>().currentRestaurantInfo;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => InvoiceScreen(
                                  order: order,
                                  restaurantName:
                                      restaurantInfo?.name.isNotEmpty == true
                                          ? restaurantInfo!.name
                                          : 'GrillPOS',
                                  restaurantPhone: restaurantInfo?.phone,
                                  restaurantAddress: restaurantInfo?.address,
                                  restaurantLogo: restaurantInfo?.logoPath,
                                ),
                              ),
                            );
                          },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(BuildContext context, String label, double value, {bool isTotal = false, bool isTax = false, double? taxRate}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (isTax)
          InkWell(
            onTap: () => _showTaxEditor(context, taxRate ?? 0.15),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.creamMuted,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.mutedColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 14, color: AppColors.mutedColor),
              ],
            ),
          )
        else
          Text(
            label,
            style: TextStyle(
              color: isTotal ? AppColors.cream : AppColors.creamMuted,
              fontSize: isTotal ? 22 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        Text(
          '${value.toStringAsFixed(2)} ج.م',
          style: TextStyle(
            color: isTotal ? AppColors.warmOrange : AppColors.cream,
            fontSize: isTotal ? 22 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showTaxEditor(BuildContext context, double currentTaxRate) {
    final ctrl = TextEditingController(text: (currentTaxRate * 100).toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.charcoalMedium,
          title: Text('تعديل نسبة الضريبة', style: TextStyle(color: AppColors.cream)),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.cream),
            decoration: InputDecoration(
              labelText: 'نسبة الضريبة (%)',
              suffixText: '%',
              labelStyle: TextStyle(color: AppColors.creamMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('إلغاء', style: TextStyle(color: AppColors.mutedColor)),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(ctrl.text);
                if (val != null && val >= 0) {
                  context.read<POSCubit>().setTaxRate(val / 100);
                  Navigator.pop(dialogCtx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmOrange),
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showTableSelector(BuildContext context, POSState state) {
    final availableTables = context.read<TablesCubit>().availableTables;
    final cubit = context.read<POSCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadius)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('اختر طاولة', style: TextStyle(color: AppColors.cream, fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.creamMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (availableTables.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('لا توجد طاولات متاحة حالياً. قم بإضافة طاولات من شاشة الطاولات.', style: TextStyle(color: AppColors.mutedColor)),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: availableTables.map((table) {
                    final selected = state.selectedTableId == table.id;
                    return InkWell(
                      onTap: () {
                        cubit.selectTable(table.id);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.warmOrange : AppColors.charcoalLight,
                          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                          border: Border.all(color: selected ? AppColors.warmOrange : AppColors.borderColor),
                        ),
                        child: Text(
                          table.displayName,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.cream,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.warmOrange,
        backgroundColor: AppColors.surfaceDark,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.creamMuted,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _TypeSegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeSegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.warmOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius - 4),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: selected ? Colors.white : AppColors.mutedColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.creamMuted,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
