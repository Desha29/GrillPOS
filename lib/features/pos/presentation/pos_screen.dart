// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/components/food_card.dart';
import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/functions/messege.dart';
import '../../../core/services/product_image_storage.dart';
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

class _POSView extends StatefulWidget {
  const _POSView();

  @override
  State<_POSView> createState() => _POSViewState();
}

class _POSViewState extends State<_POSView> {
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<MenuItem> _filterItems(POSState state) {
    if (_searchQuery.isEmpty) return state.visibleItems;
    return state.visibleItems.where((item) {
      return item.displayName.toLowerCase().contains(_searchQuery) ||
          item.name.toLowerCase().contains(_searchQuery) ||
          (item.unit?.toLowerCase().contains(_searchQuery) ?? false) ||
          (item.description?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      body: SafeArea(
        child: BlocConsumer<POSCubit, POSState>(
          listenWhen: (previous, current) =>
              previous.error != current.error && current.error != null,
          listener: (context, state) {
            if (state.error != null) {
              MotionSnackBarError(context, state.error!);
            }
          },
          builder: (context, state) {
            if (state.loading &&
                state.categories.isEmpty &&
                state.visibleItems.isEmpty) {
              return const _POSLoadingState();
            }
            if (state.error != null &&
                state.categories.isEmpty &&
                state.visibleItems.isEmpty) {
              return _POSErrorState(
                message: state.error!,
                onRetry: () => context.read<POSCubit>().loadMenu(),
              );
            }

            final filteredItems = _filterItems(state);
            return LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 1050;
                if (desktop) {
                  final cartWidth =
                      (constraints.maxWidth * .34).clamp(390.0, 510.0);
                  return Row(
                    children: [
                      Expanded(
                        child: _MenuSection(
                          state: state,
                          items: filteredItems,
                          searchController: _searchController,
                          searchQuery: _searchQuery,
                          onSearchChanged: _setSearchQuery,
                          onClearSearch: _clearSearch,
                        ),
                      ),
                      SizedBox(
                        width: cartWidth,
                        child: _CartSection(
                          state: state,
                          notesController: _notesController,
                          onCheckout: () => _checkout(context),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: _MenuSection(
                        state: state,
                        items: filteredItems,
                        searchController: _searchController,
                        searchQuery: _searchQuery,
                        onSearchChanged: _setSearchQuery,
                        onClearSearch: _clearSearch,
                      ),
                    ),
                    _MobileCartBar(
                      state: state,
                      onTap: () => _showMobileCart(context),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _setSearchQuery(String value) {
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _showMobileCart(BuildContext rootContext) async {
    final posCubit = rootContext.read<POSCubit>();
    final tablesCubit = rootContext.read<TablesCubit>();
    await showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.55),
      builder: (sheetContext) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: posCubit),
          BlocProvider.value(value: tablesCubit),
        ],
        child: FractionallySizedBox(
          heightFactor: .92,
          child: BlocBuilder<POSCubit, POSState>(
            builder: (context, state) => _CartSection(
              state: state,
              notesController: _notesController,
              compact: true,
              onCheckout: () => _checkout(
                rootContext,
                sheetContext: sheetContext,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkout(
    BuildContext navigationContext, {
    BuildContext? sheetContext,
  }) async {
    final cubit = navigationContext.read<POSCubit>();
    final notes = _notesController.text.trim();
    final order = await cubit.checkout(
      notes: notes.isEmpty ? null : notes,
    );
    if (!mounted || !navigationContext.mounted) return;

    if (order == null) return;

    _notesController.clear();
    if (sheetContext != null && sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
      await Future<void>.delayed(Duration.zero);
    }
    if (!navigationContext.mounted) return;

    final restaurantInfo = getIt<SettingsCubit>().currentRestaurantInfo;
    await Navigator.of(navigationContext).push(
      MaterialPageRoute(
        builder: (_) => InvoiceScreen(
          order: order,
          restaurantName: restaurantInfo?.name.isNotEmpty == true
              ? restaurantInfo!.name
              : 'GrillPOS',
          restaurantPhone: restaurantInfo?.phone,
          restaurantAddress: restaurantInfo?.address,
          restaurantLogo: restaurantInfo?.logoPath,
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.state,
    required this.items,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final POSState state;
  final List<MenuItem> items;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<POSCubit>();
    final selectedCategory = state.categories
        .where((category) => category.id == state.selectedCategoryId)
        .firstOrNull;

    return Container(
      color: AppColors.charcoalDark,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: ScreenHeader(
              title: 'نقطة البيع',
              subtitle: 'اختر الأصناف وأنشئ الطلب بسرعة ودقة',
              icon: Icons.point_of_sale_rounded,
              trailingWidget: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warmOrange.withOpacity(.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warmOrange.withOpacity(.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 17,
                      color: AppColors.warmOrange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${items.length} صنف',
                      style: const TextStyle(
                        color: AppColors.warmOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (state.loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.warmOrange,
              backgroundColor: Colors.transparent,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: TextStyle(color: AppColors.cream),
              decoration: InputDecoration(
                hintText: 'ابحث عن صنف بالاسم أو الوحدة...',
                hintStyle: TextStyle(color: AppColors.mutedColor),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.creamMuted,
                ),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: onClearSearch,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: AppColors.charcoalMedium,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(
                    color: AppColors.warmOrange,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 52,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  _CategoryChip(
                    label: 'كل الأصناف',
                    icon: Icons.grid_view_rounded,
                    selected: state.selectedCategoryId == null,
                    onTap: () => cubit.selectCategory(null),
                  ),
                  ...state.categories.map(
                    (category) => _CategoryChip(
                      label: category.displayName,
                      icon: Icons.restaurant_rounded,
                      selected: state.selectedCategoryId == category.id,
                      onTap: () => cubit.selectCategory(category.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedCategory?.displayName ?? 'كل الأصناف',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  searchQuery.isEmpty
                      ? '${items.length} متاح للبيع'
                      : '${items.length} نتيجة',
                  style: TextStyle(
                    color: AppColors.creamMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? _POSMenuEmptyState(
                    filtered: searchQuery.isNotEmpty,
                    onClearSearch: onClearSearch,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1120
                          ? 5
                          : constraints.maxWidth >= 820
                              ? 4
                              : constraints.maxWidth >= 550
                                  ? 3
                                  : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 224,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return FoodCard(
                            item: item,
                            onTap: () {
                              if (_isFractionalItem(item)) {
                                _showWeightPicker(context, item);
                              } else {
                                cubit.addToCart(item);
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWeightPicker(BuildContext context, MenuItem item) async {
    final cubit = context.read<POSCubit>();
    var selectedWeight = 1.0;
    final customController = TextEditingController(text: '1.000');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void setWeight(double value) {
            setDialogState(() => selectedWeight = value.clamp(.05, 50));
            customController.text = selectedWeight.toStringAsFixed(3);
          }

          return Dialog(
            insetPadding: const EdgeInsets.all(AppSpacing.md),
            backgroundColor: AppColors.charcoalMedium,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
              side: BorderSide(color: AppColors.borderColor),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.warmOrange.withOpacity(.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.scale_rounded,
                            color: AppColors.warmOrange,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'حدد الكمية',
                                style: TextStyle(
                                  color: AppColors.cream,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                item.displayName,
                                style: TextStyle(
                                  color: AppColors.creamMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: const [
                        (.25, 'ربع كيلو'),
                        (.5, 'نصف كيلو'),
                        (.75, 'كيلو إلا ربع'),
                        (1.0, '1 كيلو'),
                        (1.5, '1.5 كيلو'),
                        (2.0, '2 كيلو'),
                      ].map((preset) {
                        final selected = selectedWeight == preset.$1;
                        return ChoiceChip(
                          label: Text(preset.$2),
                          selected: selected,
                          selectedColor: AppColors.warmOrange,
                          backgroundColor: AppColors.charcoalLight,
                          side: BorderSide(
                            color: selected
                                ? AppColors.warmOrange
                                : AppColors.borderColor,
                          ),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.cream,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => setWeight(preset.$1),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.charcoalLight,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.cardRadius),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'كمية مخصصة بالكيلو',
                            style: TextStyle(
                              color: AppColors.creamMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () =>
                                    setWeight(selectedWeight - .05),
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: TextField(
                                  controller: customController,
                                  textAlign: TextAlign.center,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  style: TextStyle(
                                    color: AppColors.warmOrange,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  decoration: InputDecoration(
                                    suffixText: 'كجم',
                                    filled: true,
                                    fillColor: AppColors.charcoalMedium,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppColors.borderColor,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.warmOrange,
                                      ),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    final parsed = double.tryParse(value);
                                    if (parsed != null && parsed > 0) {
                                      setDialogState(
                                        () => selectedWeight =
                                            parsed.clamp(.05, 50),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              IconButton.filledTonal(
                                onPressed: () =>
                                    setWeight(selectedWeight + .05),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () {
                              cubit.addToCart(
                                item,
                                quantity: selectedWeight,
                              );
                              Navigator.pop(dialogContext);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.warmOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.add_shopping_cart_rounded),
                            label: const Text('إضافة للسلة'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    customController.dispose();
  }
}

class _CartSection extends StatelessWidget {
  const _CartSection({
    required this.state,
    required this.notesController,
    required this.onCheckout,
    this.compact = false,
  });

  final POSState state;
  final TextEditingController notesController;
  final Future<void> Function() onCheckout;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<POSCubit>();
    final itemCount = state.cart.fold<double>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.charcoalMedium,
        borderRadius: compact
            ? const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.dialogRadius),
              )
            : null,
        border: compact
            ? Border.all(color: AppColors.borderColor)
            : BorderDirectional(
                start: BorderSide(color: AppColors.borderColor),
              ),
      ),
      child: Column(
        children: [
          if (compact)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mutedColor.withOpacity(.45),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.warmOrange.withOpacity(.11),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_checkout_rounded,
                    color: AppColors.warmOrange,
                    size: 21,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الطلب الحالي',
                        style: TextStyle(
                          color: AppColors.cream,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        state.cart.isEmpty
                            ? 'أضف أصنافاً لبدء الطلب'
                            : '${state.cart.length} صنف • ${_formatQuantity(itemCount)} وحدة',
                        style: TextStyle(
                          color: AppColors.creamMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.cart.isNotEmpty)
                  TextButton.icon(
                    onPressed: cubit.clearCart,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.grillRed,
                      backgroundColor: AppColors.grillRed.withOpacity(.08),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                    label: const Text('إفراغ'),
                  ),
                if (compact)
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _OrderTypeSelector(
              selected: state.orderType,
              onSelected: (type) {
                cubit.setOrderType(type);
                if (type != OrderType.dineIn) {
                  cubit.selectTable(null);
                }
              },
            ),
          ),
          if (state.orderType == OrderType.dineIn)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: _TableSelectorTile(
                selectedTableId: state.selectedTableId,
                onTap: () => _showTableSelector(context, state),
                onClear: state.selectedTableId == null
                    ? null
                    : () => cubit.selectTable(null),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: state.cart.isEmpty
                ? const _EmptyCartState()
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: state.cart.length,
                    itemBuilder: (context, index) {
                      final cartItem = state.cart[index];
                      final step = _isFractionalItem(cartItem.item) ? .25 : 1.0;
                      return _POSCartItemCard(
                        cartItem: cartItem,
                        onAdd: () => cubit.updateQuantity(
                          cartItem.item.id,
                          cartItem.quantity + step,
                        ),
                        onRemove: () => cubit.updateQuantity(
                          cartItem.item.id,
                          cartItem.quantity - step,
                        ),
                        onDelete: () => cubit.removeFromCart(cartItem.item.id),
                        onAddNote: () => _showOrderNoteDialog(
                          context,
                          notesController,
                        ),
                      );
                    },
                  ),
          ),
          _CheckoutPanel(
            state: state,
            notesController: notesController,
            onEditTax: () => _showTaxEditor(context, state.taxRate),
            onCheckout: onCheckout,
          ),
        ],
      ),
    );
  }

  Future<void> _showTaxEditor(
    BuildContext context,
    double currentTaxRate,
  ) async {
    final cubit = context.read<POSCubit>();
    final controller = TextEditingController(
      text: (currentTaxRate * 100).toStringAsFixed(0),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.charcoalMedium,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
          side: BorderSide(color: AppColors.borderColor),
        ),
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.warmOrange.withOpacity(.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.percent_rounded,
            color: AppColors.warmOrange,
          ),
        ),
        title: Text(
          'نسبة الضريبة',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.cream,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: TextStyle(
            color: AppColors.cream,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            labelText: 'الضريبة',
            suffixText: '%',
            filled: true,
            fillColor: AppColors.charcoalLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value < 0 || value > 100) {
                MotionSnackBarWarning(
                  dialogContext,
                  'أدخل نسبة من 0 إلى 100',
                );
                return;
              }
              cubit.setTaxRate(value / 100);
              Navigator.pop(dialogContext);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warmOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showOrderNoteDialog(
    BuildContext context,
    TextEditingController notesController,
  ) async {
    final draftController =
        TextEditingController(text: notesController.text.trim());
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.charcoalMedium,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
          side: BorderSide(color: AppColors.borderColor),
        ),
        title: Text(
          'ملاحظات الطلب',
          style: TextStyle(
            color: AppColors.cream,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: draftController,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            style: TextStyle(color: AppColors.cream),
            decoration: InputDecoration(
              hintText: 'مثال: بدون بصل، تجهيز سريع...',
              filled: true,
              fillColor: AppColors.charcoalLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warmOrange,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('حفظ الملاحظة'),
          ),
        ],
      ),
    );
    if (saved == true) {
      notesController.text = draftController.text.trim();
      if (context.mounted) {
        MotionSnackBarSuccess(context, 'تم حفظ ملاحظة الطلب');
      }
    }
    draftController.dispose();
  }

  Future<void> _showTableSelector(
    BuildContext context,
    POSState state,
  ) async {
    final cubit = context.read<POSCubit>();
    final tablesState = context.read<TablesCubit>().state;
    final availableTables = context.read<TablesCubit>().availableTables;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        backgroundColor: AppColors.charcoalMedium,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
          side: BorderSide(color: AppColors.borderColor),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.warmOrange.withOpacity(.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.table_restaurant_rounded,
                        color: AppColors.warmOrange,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اختيار الطاولة',
                            style: TextStyle(
                              color: AppColors.cream,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${availableTables.length} طاولة متاحة حالياً',
                            style: TextStyle(
                              color: AppColors.creamMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (availableTables.isEmpty)
                  const _NoTablesState()
                else
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 150,
                        mainAxisExtent: 92,
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.sm,
                      ),
                      itemCount: availableTables.length,
                      itemBuilder: (context, index) {
                        final table = availableTables[index];
                        final selected = state.selectedTableId == table.id;
                        return InkWell(
                          onTap: () {
                            cubit.selectTable(table.id);
                            Navigator.pop(dialogContext);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.warmOrange.withOpacity(.12)
                                  : AppColors.charcoalLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? AppColors.warmOrange
                                    : AppColors.borderColor,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.table_bar_rounded,
                                  color: selected
                                      ? AppColors.warmOrange
                                      : AppColors.creamMuted,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  table.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.cream,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (tablesState.loading)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: LinearProgressIndicator(
                      color: AppColors.warmOrange,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderTypeSelector extends StatelessWidget {
  const _OrderTypeSelector({
    required this.selected,
    required this.onSelected,
  });

  final OrderType selected;
  final ValueChanged<OrderType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.charcoalDark,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          _OrderTypeButton(
            label: 'داخلي',
            icon: Icons.restaurant_rounded,
            selected: selected == OrderType.dineIn,
            onTap: () => onSelected(OrderType.dineIn),
          ),
          _OrderTypeButton(
            label: 'تيك أواي',
            icon: Icons.takeout_dining_rounded,
            selected: selected == OrderType.takeaway,
            onTap: () => onSelected(OrderType.takeaway),
          ),
          _OrderTypeButton(
            label: 'توصيل',
            icon: Icons.delivery_dining_rounded,
            selected: selected == OrderType.delivery,
            onTap: () => onSelected(OrderType.delivery),
          ),
        ],
      ),
    );
  }
}

class _OrderTypeButton extends StatelessWidget {
  const _OrderTypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.warmOrange : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? Colors.white : AppColors.creamMuted,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.creamMuted,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TableSelectorTile extends StatelessWidget {
  const _TableSelectorTile({
    required this.selectedTableId,
    required this.onTap,
    required this.onClear,
  });

  final String? selectedTableId;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TablesCubit, TablesState>(
      builder: (context, tablesState) {
        var label = 'اختر طاولة (اختياري)';
        if (selectedTableId != null) {
          final selected = tablesState.tables
              .where((table) => table.id == selectedTableId)
              .firstOrNull;
          label = selected == null
              ? 'تم اختيار الطاولة'
              : 'الطاولة: ${selected.displayName}';
        }
        return Material(
          color: AppColors.charcoalLight,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: selectedTableId == null
                      ? AppColors.borderColor
                      : AppColors.warmOrange.withOpacity(.45),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.table_restaurant_outlined,
                    color: AppColors.warmOrange,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.cream,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onClear != null)
                    InkWell(
                      onTap: onClear,
                      borderRadius: BorderRadius.circular(99),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.creamMuted,
                          size: 17,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.creamMuted,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _POSCartItemCard extends StatelessWidget {
  const _POSCartItemCard({
    required this.cartItem,
    required this.onAdd,
    required this.onRemove,
    required this.onDelete,
    required this.onAddNote,
  });

  final PosCartItem cartItem;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onDelete;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    final item = cartItem.item;
    final minimumQuantity = _isFractionalItem(item) ? .25 : 1.0;
    final removeNext = cartItem.quantity <= minimumQuantity;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 58,
              height: 58,
              child: ProductImageView(
                source: item.imageUrl,
                semanticLabel: 'صورة ${item.displayName}',
                placeholder: const ProductImagePlaceholder(iconSize: 25),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.cream,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${cartItem.lineTotal.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(
                        color: AppColors.warmOrange,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.price.toStringAsFixed(2)} ج.م${item.unit == null ? '' : ' / ${item.unit}'}',
                  style: TextStyle(
                    color: AppColors.creamMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _CartQuantityButton(
                      icon: removeNext
                          ? Icons.delete_outline_rounded
                          : Icons.remove_rounded,
                      onTap: onRemove,
                      danger: removeNext,
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 58),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      alignment: Alignment.center,
                      child: Text(
                        '${_formatQuantity(cartItem.quantity)}${item.unit == null ? '' : ' ${item.unit}'}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.cream,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _CartQuantityButton(
                      icon: Icons.add_rounded,
                      onTap: onAdd,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'ملاحظة للطلب',
                      visualDensity: VisualDensity.compact,
                      onPressed: onAddNote,
                      icon: Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.creamMuted,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      tooltip: 'حذف من الطلب',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.grillRed,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartQuantityButton extends StatelessWidget {
  const _CartQuantityButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.grillRed : AppColors.cream;
    return Material(
      color: danger
          ? AppColors.grillRed.withOpacity(.09)
          : AppColors.charcoalMedium,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 29,
          height: 29,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: danger
                  ? AppColors.grillRed.withOpacity(.4)
                  : AppColors.borderColor,
            ),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

class _CheckoutPanel extends StatelessWidget {
  const _CheckoutPanel({
    required this.state,
    required this.notesController,
    required this.onEditTax,
    required this.onCheckout,
  });

  final POSState state;
  final TextEditingController notesController;
  final VoidCallback onEditTax;
  final Future<void> Function() onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.charcoalDark,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesController,
              minLines: 1,
              maxLines: 2,
              style: TextStyle(color: AppColors.cream, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'ملاحظات الطلب (اختياري)',
                hintStyle: TextStyle(color: AppColors.mutedColor),
                prefixIcon: Icon(
                  Icons.sticky_note_2_outlined,
                  color: AppColors.creamMuted,
                  size: 18,
                ),
                filled: true,
                fillColor: AppColors.charcoalMedium,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.warmOrange),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _AmountRow(label: 'المجموع الفرعي', value: state.subtotal),
            const SizedBox(height: 4),
            _AmountRow(
              label: 'الضريبة (${(state.taxRate * 100).toStringAsFixed(0)}%)',
              value: state.tax,
              onTap: onEditTax,
            ),
            Divider(color: AppColors.borderColor, height: 14),
            _AmountRow(
              label: 'الإجمالي',
              value: state.total,
              total: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    state.cart.isEmpty || state.loading ? null : onCheckout,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warmOrange,
                  disabledBackgroundColor: AppColors.charcoalLight,
                  disabledForegroundColor: AppColors.mutedColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.buttonRadius),
                  ),
                ),
                icon: state.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.receipt_long_rounded),
                label: Text(
                  state.loading
                      ? 'جاري حفظ الطلب...'
                      : 'إتمام الطلب وطباعة الفاتورة',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.total = false,
    this.onTap,
  });

  final String label;
  final double value;
  final bool total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: total ? AppColors.cream : AppColors.creamMuted,
            fontSize: total ? 16 : 12,
            fontWeight: total ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.edit_outlined, size: 13, color: AppColors.creamMuted),
        ],
      ],
    );
    return Row(
      children: [
        if (onTap == null)
          labelWidget
        else
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: labelWidget,
            ),
          ),
        const Spacer(),
        Text(
          '${value.toStringAsFixed(2)} ج.م',
          style: TextStyle(
            color: total ? AppColors.warmOrange : AppColors.cream,
            fontSize: total ? 20 : 13,
            fontWeight: total ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MobileCartBar extends StatelessWidget {
  const _MobileCartBar({required this.state, required this.onTap});

  final POSState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.charcoalMedium,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Material(
          color: AppColors.warmOrange,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.shopping_cart_checkout_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                      if (state.cart.isNotEmpty)
                        PositionedDirectional(
                          top: -8,
                          end: -9,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.grillRed,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Text(
                              '${state.cart.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.cart.isEmpty
                              ? 'فتح الطلب الحالي'
                              : 'مراجعة وإتمام الطلب',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _orderTypeLabel(state.orderType),
                          style: TextStyle(
                            color: Colors.white.withOpacity(.78),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${state.total.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
      child: Material(
        color: selected ? AppColors.warmOrange : AppColors.charcoalMedium,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
              border: Border.all(
                color: selected ? AppColors.warmOrange : AppColors.borderColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.creamMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.cream,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  const _EmptyCartState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: AppColors.warmOrange.withOpacity(.08),
                borderRadius: BorderRadius.circular(21),
              ),
              child: const Icon(
                Icons.add_shopping_cart_rounded,
                color: AppColors.warmOrange,
                size: 31,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'السلة جاهزة',
              style: TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'اضغط على أي صنف لإضافته إلى الطلب',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.creamMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _POSMenuEmptyState extends StatelessWidget {
  const _POSMenuEmptyState({
    required this.filtered,
    required this.onClearSearch,
  });

  final bool filtered;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtered ? Icons.search_off_rounded : Icons.no_food_rounded,
            color: AppColors.mutedColor,
            size: 48,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            filtered ? 'لا توجد نتائج مطابقة' : 'لا توجد أصناف متاحة',
            style: TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            filtered
                ? 'جرّب البحث بكلمة أخرى'
                : 'راجع حالة الأصناف من شاشة إدارة المنيو',
            style: TextStyle(color: AppColors.creamMuted, fontSize: 12),
          ),
          if (filtered) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onClearSearch,
              icon: const Icon(Icons.close_rounded),
              label: const Text('مسح البحث'),
            ),
          ],
        ],
      ),
    );
  }
}

class _POSLoadingState extends StatelessWidget {
  const _POSLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.warmOrange),
          const SizedBox(height: AppSpacing.md),
          Text(
            'جاري تجهيز نقطة البيع...',
            style: TextStyle(color: AppColors.creamMuted),
          ),
        ],
      ),
    );
  }
}

class _POSErrorState extends StatelessWidget {
  const _POSErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.charcoalMedium,
          borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.grillRed,
              size: 46,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'تعذر تحميل نقطة البيع',
              style: TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.creamMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warmOrange,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoTablesState extends StatelessWidget {
  const _NoTablesState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          Icon(
            Icons.table_restaurant_outlined,
            color: AppColors.mutedColor,
            size: 36,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'لا توجد طاولات متاحة حالياً',
            style: TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'يمكنك إدارة الطاولات من شاشة الطاولات',
            style: TextStyle(color: AppColors.creamMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

bool _isFractionalItem(MenuItem item) {
  final unit = item.unit?.trim().toLowerCase() ?? '';
  return unit.contains('كيلو') ||
      unit.contains('كجم') ||
      unit == 'kg' ||
      const {'cat_grills', 'cat_kebab', 'cat_kofta'}.contains(item.categoryId);
}

String _formatQuantity(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
}

String _orderTypeLabel(OrderType type) {
  return switch (type) {
    OrderType.dineIn => 'طلب داخلي',
    OrderType.takeaway => 'تيك أواي',
    OrderType.delivery => 'طلب توصيل',
  };
}
