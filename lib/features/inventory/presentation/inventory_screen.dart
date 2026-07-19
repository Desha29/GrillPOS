import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/functions/messege.dart';
import '../../auth/presentation/cubit/user_cubit.dart';
import '../data/inventory_models.dart';
import 'cubit/inventory_cubit.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<InventoryCubit>()..load(),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: _InventoryView(),
      ),
    );
  }
}

class _InventoryView extends StatefulWidget {
  const _InventoryView();

  @override
  State<_InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<_InventoryView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createProduct() async {
    final cubit = context.read<InventoryCubit>();
    final input = await showDialog<NewInventoryProductInput>(
      context: context,
      builder: (_) => _ProductDialog(suppliers: cubit.state.suppliers),
    );
    if (input == null || !mounted) return;
    final saved = await cubit.createProduct(
      input,
      userId: getIt<UserCubit>().currentUser.username,
    );
    if (!mounted) return;
    if (saved) {
      MotionSnackBarSuccess(context, 'Product added to inventory.');
    } else {
      MotionSnackBarError(
          context, cubit.state.error ?? 'Could not save product.');
    }
  }

  Future<void> _createSupplier() async {
    final cubit = context.read<InventoryCubit>();
    final input = await showDialog<NewSupplierInput>(
      context: context,
      builder: (_) => const _SupplierDialog(),
    );
    if (input == null || !mounted) return;
    final saved = await cubit.createSupplier(input);
    if (!mounted) return;
    if (saved) {
      MotionSnackBarSuccess(context, 'Supplier saved.');
    } else {
      MotionSnackBarError(
          context, cubit.state.error ?? 'Could not save supplier.');
    }
  }

  Future<void> _editProduct(InventoryProduct product) async {
    final cubit = context.read<InventoryCubit>();
    final input = await showDialog<NewInventoryProductInput>(
      context: context,
      builder: (_) => _ProductDialog(
        suppliers: cubit.state.suppliers,
        product: product,
      ),
    );
    if (input == null || !mounted) return;
    final saved = await cubit.updateProduct(product, input);
    if (!mounted) return;
    if (saved) {
      MotionSnackBarSuccess(context, 'Product details updated.');
    } else {
      MotionSnackBarError(
        context,
        cubit.state.error ?? 'Could not update product.',
      );
    }
  }

  Future<void> _manageStock(InventoryProduct product) async {
    final action = await showDialog<_StockAction>(
      context: context,
      builder: (_) => _StockDialog(product: product),
    );
    if (action == null || !mounted) return;
    final cubit = context.read<InventoryCubit>();
    final userId = getIt<UserCubit>().currentUser.username;
    final saved = action.serials != null
        ? await cubit.addSerials(product, action.serials!, userId: userId)
        : await cubit.adjustStock(
            product,
            action.quantity!,
            action.note,
            userId: userId,
          );
    if (!mounted) return;
    if (saved) {
      MotionSnackBarSuccess(context, 'Inventory updated successfully.');
    } else {
      MotionSnackBarError(
          context, cubit.state.error ?? 'Could not update stock.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      body: SafeArea(
        child: BlocConsumer<InventoryCubit, InventoryState>(
          listenWhen: (previous, current) =>
              previous.error != current.error && current.error != null,
          listener: (context, state) {
            if (state.error != null) MotionSnackBarError(context, state.error!);
          },
          builder: (context, state) {
            return RefreshIndicator(
              color: AppColors.warmOrange,
              onRefresh: () => context.read<InventoryCubit>().load(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: ScreenHeader(
                        title: 'Inventory & Products',
                        subtitle:
                            'Computer parts, serialized devices, suppliers and stock control',
                        icon: LucideIcons.warehouse,
                        trailingWidget: _HeaderActions(
                          onAddProduct: _createProduct,
                          onAddSupplier: _createSupplier,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _StatsGrid(stats: state.stats),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _InventoryToolbar(
                        controller: _searchController,
                        lowStockOnly: state.lowStockOnly,
                        resultCount: state.products.length,
                        onSearch: (value) =>
                            context.read<InventoryCubit>().load(search: value),
                        onLowStockChanged: (value) => context
                            .read<InventoryCubit>()
                            .load(lowStockOnly: value),
                      ),
                    ),
                  ),
                  if (state.loading && state.products.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.warmOrange,
                        ),
                      ),
                    )
                  else if (state.products.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyInventory(onAddProduct: _createProduct),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.crossAxisExtent >= 1100
                              ? 3
                              : constraints.crossAxisExtent >= 700
                                  ? 2
                                  : 1;
                          return SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _ProductCard(
                                product: state.products[index],
                                onManageStock: () =>
                                    _manageStock(state.products[index]),
                                onEdit: () =>
                                    _editProduct(state.products[index]),
                              ),
                              childCount: state.products.length,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: AppSpacing.md,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisExtent: 242,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.onAddProduct,
    required this.onAddSupplier,
  });

  final VoidCallback onAddProduct;
  final VoidCallback onAddSupplier;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    if (compact) {
      return PopupMenuButton<String>(
        tooltip: 'Inventory actions',
        color: AppColors.charcoalMedium,
        icon: const Icon(LucideIcons.plus, color: AppColors.warmOrange),
        onSelected: (value) =>
            value == 'product' ? onAddProduct() : onAddSupplier(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'product', child: Text('New product')),
          PopupMenuItem(value: 'supplier', child: Text('New supplier')),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: onAddSupplier,
          icon: const Icon(LucideIcons.truck, size: 18),
          label: const Text('Supplier'),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          onPressed: onAddProduct,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.warmOrange,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('New product'),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final InventoryStats stats;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    final cards = [
      _StatData('Products', '${stats.products}', LucideIcons.package,
          AppColors.blueMuted),
      _StatData('Low stock', '${stats.lowStock}', LucideIcons.triangleAlert,
          stats.lowStock > 0 ? AppColors.grillRed : AppColors.successGreen),
      _StatData('Serialized units', '${stats.serializedUnits}',
          LucideIcons.scanLine, const Color(0xFF8B5CF6)),
      _StatData('Inventory value', currency.format(stats.inventoryValue),
          LucideIcons.circleDollarSign, AppColors.successGreen),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width >= 1000
            ? (width - AppSpacing.md * 3) / 4
            : width >= 560
                ? (width - AppSpacing.md) / 2
                : width;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: cards
              .map((data) => SizedBox(
                    width: itemWidth,
                    child: _StatCard(data: data),
                  ))
              .toList(growable: false),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: data.color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(data.label,
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryToolbar extends StatelessWidget {
  const _InventoryToolbar({
    required this.controller,
    required this.lowStockOnly,
    required this.resultCount,
    required this.onSearch,
    required this.onLowStockChanged,
  });

  final TextEditingController controller;
  final bool lowStockOnly;
  final int resultCount;
  final ValueChanged<String> onSearch;
  final ValueChanged<bool> onLowStockChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final search = TextField(
          controller: controller,
          onSubmitted: onSearch,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search name, SKU, barcode, brand or model',
            prefixIcon: const Icon(LucideIcons.search, size: 20),
            suffixIcon: IconButton(
              tooltip: 'Search',
              onPressed: () => onSearch(controller.text),
              icon: const Icon(LucideIcons.arrowRight, size: 18),
            ),
          ),
        );
        final filters = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilterChip(
              selected: lowStockOnly,
              onSelected: onLowStockChanged,
              avatar: Icon(
                LucideIcons.triangleAlert,
                size: 16,
                color: lowStockOnly ? Colors.white : AppColors.ember,
              ),
              label: const Text('Low stock only'),
              selectedColor: AppColors.grillRed,
              checkmarkColor: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              '$resultCount results',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              search,
              const SizedBox(height: AppSpacing.sm),
              filters,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: AppSpacing.md),
            filters,
          ],
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onManageStock,
    required this.onEdit,
  });

  final InventoryProduct product;
  final VoidCallback onManageStock;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2);
    final warning = product.isLowStock;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onManageStock,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: _cardDecoration(
            borderColor:
                warning ? AppColors.grillRed.withValues(alpha: .45) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.blueMuted.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      product.trackSerials
                          ? LucideIcons.monitorSmartphone
                          : LucideIcons.package,
                      color: AppColors.blueMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          product.descriptor.isNotEmpty
                              ? product.descriptor
                              : product.categoryName ?? 'Uncategorized',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Product actions',
                    color: AppColors.charcoalMedium,
                    icon: Icon(LucideIcons.ellipsisVertical,
                        color: AppColors.mutedColor, size: 19),
                    onSelected: (value) =>
                        value == 'edit' ? onEdit() : onManageStock(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'stock',
                        child: ListTile(
                          dense: true,
                          leading: Icon(LucideIcons.packageCheck, size: 18),
                          title: Text('Manage stock'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          leading: Icon(LucideIcons.pencil, size: 18),
                          title: Text('Edit details'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (product.sku?.isNotEmpty ?? false)
                    _Tag(label: 'SKU ${product.sku}', icon: LucideIcons.hash),
                  if (product.trackSerials)
                    const _Tag(
                        label: 'Serial tracked', icon: LucideIcons.scanLine),
                  if (product.warrantyMonths > 0)
                    _Tag(
                      label: '${product.warrantyMonths} mo warranty',
                      icon: LucideIcons.shieldCheck,
                    ),
                ],
              ),
              const Spacer(),
              Divider(color: AppColors.borderColor, height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ProductMetric(
                      label: warning ? 'LOW STOCK' : 'IN STOCK',
                      value: _formatQuantity(product.stock),
                      color:
                          warning ? AppColors.grillRed : AppColors.successGreen,
                    ),
                  ),
                  Expanded(
                    child: _ProductMetric(
                      label: 'SELL PRICE',
                      value: money.format(product.price),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductMetric extends StatelessWidget {
  const _ProductMetric({
    required this.label,
    required this.value,
    this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              color: color ?? AppColors.mutedColor,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: .7,
            )),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            )),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory({required this.onAddProduct});

  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.warmOrange.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.packageOpen,
                  color: AppColors.warmOrange, size: 40),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No inventory products found',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 6),
            Text('Add computer parts, accessories or serialized devices.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onAddProduct,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warmOrange,
              ),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Add first product'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({required this.suppliers, this.product});

  final List<Supplier> suppliers;
  final InventoryProduct? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _category = TextEditingController();
  final _cost = TextEditingController(text: '0');
  final _price = TextEditingController(text: '0');
  final _stock = TextEditingController(text: '0');
  final _minStock = TextEditingController(text: '1');
  final _warranty = TextEditingController(text: '0');
  final _serials = TextEditingController();
  String? _supplierId;
  bool _trackSerials = false;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) return;
    _name.text = product.name;
    _sku.text = product.sku ?? '';
    _barcode.text = product.barcode ?? '';
    _brand.text = product.brand ?? '';
    _model.text = product.model ?? '';
    _category.text = product.categoryName ?? '';
    _cost.text = product.cost.toStringAsFixed(2);
    _price.text = product.price.toStringAsFixed(2);
    _stock.text = product.stock.toString();
    _minStock.text = product.minStock.toString();
    _warranty.text = product.warrantyMonths.toString();
    _supplierId = product.supplierId;
    _trackSerials = product.trackSerials;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sku,
      _barcode,
      _brand,
      _model,
      _category,
      _cost,
      _price,
      _stock,
      _minStock,
      _warranty,
      _serials,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final serialNumbers = _splitSerials(_serials.text);
    if (!_editing && _trackSerials && serialNumbers.isEmpty) {
      MotionSnackBarWarning(context, 'Add at least one serial number.');
      return;
    }
    Navigator.pop(
      context,
      NewInventoryProductInput(
        name: _name.text.trim(),
        sku: _sku.text,
        barcode: _barcode.text,
        brand: _brand.text,
        model: _model.text,
        categoryName: _category.text,
        supplierId: _supplierId,
        cost: double.parse(_cost.text),
        price: double.parse(_price.text),
        openingStock: double.parse(_stock.text),
        minStock: double.parse(_minStock.text),
        warrantyMonths: int.parse(_warranty.text),
        trackSerials: _trackSerials,
        serialNumbers: serialNumbers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: _editing ? 'Edit product details' : 'Add inventory product',
      subtitle: _editing
          ? 'Update pricing, supplier, warranty and product information.'
          : 'Create a sellable product with purchasing and warranty data.',
      icon: _editing ? LucideIcons.pencil : LucideIcons.packagePlus,
      actionLabel: _editing ? 'Save changes' : 'Save product',
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _ResponsiveFields(children: [
              _AppField(
                controller: _name,
                label: 'Product name *',
                validator: _required,
              ),
              _AppField(controller: _sku, label: 'SKU'),
            ]),
            _ResponsiveFields(children: [
              _AppField(controller: _barcode, label: 'Barcode'),
              _AppField(controller: _category, label: 'Category'),
            ]),
            _ResponsiveFields(children: [
              _AppField(controller: _brand, label: 'Brand'),
              _AppField(controller: _model, label: 'Model'),
            ]),
            _ResponsiveFields(children: [
              _AppField(
                controller: _cost,
                label: 'Unit cost *',
                number: true,
                validator: _nonNegative,
              ),
              _AppField(
                controller: _price,
                label: 'Sell price *',
                number: true,
                validator: _nonNegative,
              ),
            ]),
            _ResponsiveFields(children: [
              _AppField(
                controller: _stock,
                label: _editing ? 'Current stock' : 'Opening stock',
                number: true,
                enabled: !_editing && !_trackSerials,
                validator: _nonNegative,
              ),
              _AppField(
                controller: _minStock,
                label: 'Low-stock level',
                number: true,
                validator: _nonNegative,
              ),
            ]),
            _ResponsiveFields(children: [
              DropdownButtonFormField<String?>(
                initialValue: _supplierId,
                decoration: const InputDecoration(labelText: 'Supplier'),
                dropdownColor: AppColors.charcoalMedium,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No supplier'),
                  ),
                  ...widget.suppliers.map(
                    (supplier) => DropdownMenuItem<String?>(
                      value: supplier.id,
                      child: Text(supplier.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _supplierId = value),
              ),
              _AppField(
                controller: _warranty,
                label: 'Warranty months',
                number: true,
                validator: _wholeNonNegative,
              ),
            ]),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.charcoalLight,
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Track individual serial numbers',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    )),
                subtitle: Text(
                  'Recommended for computers, monitors, phones and warranty items.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                value: _trackSerials,
                activeTrackColor: AppColors.warmOrange,
                onChanged: _editing
                    ? null
                    : (value) => setState(() => _trackSerials = value),
              ),
            ),
            if (_trackSerials && !_editing) ...[
              const SizedBox(height: 12),
              _AppField(
                controller: _serials,
                label: 'Serial numbers *',
                hint: 'One per line, or separated with commas',
                maxLines: 4,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupplierDialog extends StatefulWidget {
  const _SupplierDialog();

  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _tax = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _name,
      _contact,
      _phone,
      _email,
      _address,
      _tax,
      _notes
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      NewSupplierInput(
        name: _name.text.trim(),
        contactName: _contact.text,
        phone: _phone.text,
        email: _email.text,
        address: _address.text,
        taxNumber: _tax.text,
        notes: _notes.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: 'New supplier',
      subtitle: 'Keep purchasing contacts and tax details in one place.',
      icon: LucideIcons.truck,
      actionLabel: 'Save supplier',
      onSubmit: _submit,
      maxWidth: 620,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _ResponsiveFields(children: [
              _AppField(
                  controller: _name,
                  label: 'Supplier name *',
                  validator: _required),
              _AppField(controller: _contact, label: 'Contact person'),
            ]),
            _ResponsiveFields(children: [
              _AppField(controller: _phone, label: 'Phone'),
              _AppField(controller: _email, label: 'Email'),
            ]),
            _ResponsiveFields(children: [
              _AppField(controller: _tax, label: 'Tax number'),
              _AppField(controller: _address, label: 'Address'),
            ]),
            _AppField(
              controller: _notes,
              label: 'Notes',
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}

class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.product});

  final InventoryProduct product;

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  final _serials = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    _serials.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.product.trackSerials) {
      final serials = _splitSerials(_serials.text);
      if (serials.isEmpty) {
        MotionSnackBarWarning(context, 'Add at least one serial number.');
        return;
      }
      Navigator.pop(context, _StockAction.serials(serials));
      return;
    }
    Navigator.pop(
      context,
      _StockAction.adjustment(
        double.parse(_quantity.text),
        _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serialized = widget.product.trackSerials;
    return _DialogShell(
      title: serialized ? 'Receive serialized stock' : 'Adjust stock',
      subtitle:
          '${widget.product.name} • ${_formatQuantity(widget.product.stock)} in stock',
      icon: serialized ? LucideIcons.scanLine : LucideIcons.packageCheck,
      actionLabel: serialized ? 'Receive units' : 'Apply adjustment',
      onSubmit: _submit,
      maxWidth: 560,
      child: Form(
        key: _formKey,
        child: Column(
          children: serialized
              ? [
                  _AppField(
                    controller: _serials,
                    label: 'New serial numbers *',
                    hint: 'One per line, or separated with commas',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 8),
                  _InfoBanner(
                    text:
                        'Every serial is unique across inventory. Stock quantity will increase automatically.',
                  ),
                ]
              : [
                  _AppField(
                    controller: _quantity,
                    label: 'Quantity change *',
                    hint: 'Use a negative value to remove stock',
                    number: true,
                    validator: _nonZero,
                  ),
                  const SizedBox(height: 12),
                  _AppField(
                    controller: _note,
                    label: 'Reason / note *',
                    maxLines: 3,
                    validator: _required,
                  ),
                  const SizedBox(height: 8),
                  const _InfoBanner(
                    text:
                        'All stock changes are recorded in the movement history with the current user.',
                  ),
                ],
        ),
      ),
    );
  }
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.onSubmit,
    required this.child,
    this.maxWidth = 760,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onSubmit;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Dialog(
        insetPadding: const EdgeInsets.all(18),
        backgroundColor: Colors.transparent,
        child: Container(
          width: maxWidth,
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          decoration: BoxDecoration(
            color: AppColors.charcoalMedium,
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
            border: Border.all(color: AppColors.borderColor),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.warmOrange.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: AppColors.warmOrange),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  )),
                          const SizedBox(height: 3),
                          Text(subtitle,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              )),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.borderColor),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: child,
                ),
              ),
              Divider(height: 1, color: AppColors.borderColor),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: onSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.warmOrange,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: Text(actionLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final row = constraints.maxWidth >= 520;
        if (!row) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(width: 12),
                Expanded(child: children[index]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AppField extends StatelessWidget {
  const _AppField({
    required this.controller,
    required this.label,
    this.hint,
    this.number = false,
    this.enabled = true,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool number;
  final bool enabled;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : null,
      validator: validator,
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blueMuted.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blueMuted.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, color: AppColors.blueMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
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

class _StockAction {
  const _StockAction._({this.quantity, this.serials, this.note = ''});

  factory _StockAction.adjustment(double quantity, String note) =>
      _StockAction._(quantity: quantity, note: note);
  factory _StockAction.serials(List<String> serials) =>
      _StockAction._(serials: serials);

  final double? quantity;
  final List<String>? serials;
  final String note;
}

BoxDecoration _cardDecoration({Color? borderColor}) => BoxDecoration(
      color: AppColors.charcoalMedium,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      border: Border.all(color: borderColor ?? AppColors.borderColor),
      boxShadow: AppColors.isDarkMode
          ? null
          : const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
    );

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

List<String> _splitSerials(String value) => value
    .split(RegExp(r'[,;\n\r]+'))
    .map((serial) => serial.trim())
    .where((serial) => serial.isNotEmpty)
    .toSet()
    .toList(growable: false);

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

String? _nonNegative(String? value) {
  final number = double.tryParse(value ?? '');
  if (number == null) return 'Enter a valid number.';
  return number < 0 ? 'Value cannot be negative.' : null;
}

String? _wholeNonNegative(String? value) {
  final number = int.tryParse(value ?? '');
  if (number == null) return 'Enter a whole number.';
  return number < 0 ? 'Value cannot be negative.' : null;
}

String? _nonZero(String? value) {
  final number = double.tryParse(value ?? '');
  if (number == null) return 'Enter a valid number.';
  return number == 0 ? 'Quantity cannot be zero.' : null;
}
