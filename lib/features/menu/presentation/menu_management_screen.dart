// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/functions/messege.dart';
import '../../../core/services/product_image_storage.dart';
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

enum _AvailabilityFilter { all, available, unavailable }

enum _CategoryAction { edit, delete }

class _MenuManagementView extends StatefulWidget {
  const _MenuManagementView();

  @override
  State<_MenuManagementView> createState() => _MenuManagementViewState();
}

class _MenuManagementViewState extends State<_MenuManagementView> {
  final _searchController = TextEditingController();
  _AvailabilityFilter _availabilityFilter = _AvailabilityFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MenuItem> _visibleItems(MenuState state) {
    return state.items.where((item) {
      final queryMatches = _query.isEmpty ||
          item.displayName.toLowerCase().contains(_query) ||
          item.name.toLowerCase().contains(_query) ||
          (item.unit?.toLowerCase().contains(_query) ?? false) ||
          (item.description?.toLowerCase().contains(_query) ?? false);
      final availabilityMatches = switch (_availabilityFilter) {
        _AvailabilityFilter.all => true,
        _AvailabilityFilter.available => item.isAvailable,
        _AvailabilityFilter.unavailable => !item.isAvailable,
      };
      return queryMatches && availabilityMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      body: SafeArea(
        child: BlocConsumer<MenuCubit, MenuState>(
          listener: (context, state) {
            if (state.error != null) {
              MotionSnackBarError(context, state.error!);
            }
          },
          builder: (context, state) {
            final visibleItems = _visibleItems(state);
            final selectedCategory = state.categories
                .where((category) => category.id == state.selectedCategoryId)
                .firstOrNull;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    0,
                  ),
                  child: ScreenHeader(
                    title: 'إدارة المنيو',
                    subtitle:
                        'نظّم الأصناف والتصنيفات والأسعار وحالة التوفر من مكان واحد',
                    icon: Icons.restaurant_menu_rounded,
                    trailingWidget: compactHeader
                        ? _CompactHeaderAction(
                            onPressed: () => _showItemDialog(context),
                          )
                        : _HeaderActions(
                            onAddCategory: () => _showCategoryDialog(context),
                            onAddItem: () => _showItemDialog(context),
                          ),
                  ),
                ),
                if (state.loading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.warmOrange,
                    backgroundColor: Colors.transparent,
                  ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.warmOrange,
                    onRefresh: () => context.read<MenuCubit>().loadMenu(
                          categoryId: state.selectedCategoryId,
                          clearCategory: state.selectedCategoryId == null,
                        ),
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
                            child: _OverviewStrip(state: state),
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
                            child: _MenuToolbar(
                              controller: _searchController,
                              filter: _availabilityFilter,
                              onQueryChanged: (value) => setState(
                                () => _query = value.trim().toLowerCase(),
                              ),
                              onClear: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              onFilterChanged: (value) =>
                                  setState(() => _availabilityFilter = value),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          sliver: SliverToBoxAdapter(
                            child: _CategoryNavigation(
                              categories: state.categories,
                              selectedCategoryId: state.selectedCategoryId,
                              onSelect: (id) =>
                                  context.read<MenuCubit>().selectCategory(id),
                              onAdd: () => _showCategoryDialog(context),
                              onEdit: (category) =>
                                  _showCategoryDialog(context, category),
                              onDelete: (category) =>
                                  _deleteCategory(context, category),
                            ),
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
                            child: _ResultsHeader(
                              categoryName:
                                  selectedCategory?.displayName ?? 'كل الأصناف',
                              visibleCount: visibleItems.length,
                              totalCount: state.items.length,
                              filtered: _query.isNotEmpty ||
                                  _availabilityFilter !=
                                      _AvailabilityFilter.all,
                            ),
                          ),
                        ),
                        if (state.loading &&
                            state.categories.isEmpty &&
                            state.items.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _MenuLoadingState(),
                          )
                        else if (visibleItems.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _MenuEmptyState(
                              isFiltered: _query.isNotEmpty ||
                                  _availabilityFilter !=
                                      _AvailabilityFilter.all,
                              categoryName: selectedCategory?.displayName,
                              onClearFilters: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _availabilityFilter = _AvailabilityFilter.all;
                                });
                              },
                              onAddItem: () => _showItemDialog(context),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              96,
                            ),
                            sliver: SliverLayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.crossAxisExtent;
                                final columns = width >= 1180
                                    ? 3
                                    : width >= 720
                                        ? 2
                                        : 1;
                                return SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisExtent: 204,
                                    crossAxisSpacing: AppSpacing.md,
                                    mainAxisSpacing: AppSpacing.md,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final item = visibleItems[index];
                                      final category = state.categories
                                          .where((candidate) =>
                                              candidate.id == item.categoryId)
                                          .firstOrNull;
                                      return _MenuItemCard(
                                        item: item,
                                        categoryName:
                                            category?.displayName ?? 'غير مصنف',
                                        onEdit: () =>
                                            _showItemDialog(context, item),
                                        onAvailabilityChanged: (value) =>
                                            context
                                                .read<MenuCubit>()
                                                .toggleItemAvailability(
                                                  item.id,
                                                  value,
                                                ),
                                      );
                                    },
                                    childCount: visibleItems.length,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: MediaQuery.sizeOf(context).width < 720
          ? FloatingActionButton.extended(
              heroTag: 'menu-add-item',
              backgroundColor: AppColors.warmOrange,
              foregroundColor: Colors.white,
              elevation: 4,
              onPressed: () => _showItemDialog(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'صنف جديد',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  Future<void> _deleteCategory(
    BuildContext context,
    MenuCategory category,
  ) async {
    final confirmed = await _showDeleteConfirmation(
      context,
      title: 'حذف التصنيف؟',
      message:
          'سيتم إخفاء تصنيف "${category.displayName}" من المنيو. لن يتم حذف الأصناف التابعة له.',
      confirmLabel: 'حذف التصنيف',
    );
    if (!confirmed || !context.mounted) return;
    await context.read<MenuCubit>().deleteCategory(category.id);
    if (context.mounted) {
      MotionSnackBarSuccess(context, 'تم حذف التصنيف');
    }
  }

  Future<void> _showCategoryDialog(
    BuildContext context, [
    MenuCategory? category,
  ]) async {
    final cubit = context.read<MenuCubit>();
    final controller = TextEditingController(text: category?.displayName ?? '');
    final isEditing = category != null;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _EditorDialog(
        icon: isEditing ? Icons.edit_rounded : Icons.category_rounded,
        title: isEditing ? 'تعديل التصنيف' : 'تصنيف جديد',
        subtitle: isEditing
            ? 'حدّث اسم التصنيف الظاهر في المنيو'
            : 'أنشئ مجموعة واضحة لتنظيم أصناف المنيو',
        body: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          style: TextStyle(color: AppColors.cream),
          decoration: _fieldDecoration(
            label: 'اسم التصنيف',
            hint: 'مثال: المشويات',
            icon: Icons.category_outlined,
          ),
          onSubmitted: (_) => _saveCategory(
            dialogContext,
            cubit,
            controller,
            category,
          ),
        ),
        leadingAction: isEditing
            ? TextButton.icon(
                onPressed: () async {
                  final confirmed = await _showDeleteConfirmation(
                    dialogContext,
                    title: 'حذف التصنيف؟',
                    message:
                        'سيتم إخفاء تصنيف "${category.displayName}" مع الاحتفاظ بالأصناف.',
                    confirmLabel: 'حذف',
                  );
                  if (!confirmed) return;
                  await cubit.deleteCategory(category.id);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('حذف'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.grillRed,
                ),
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => _saveCategory(
              dialogContext,
              cubit,
              controller,
              category,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warmOrange,
              foregroundColor: Colors.white,
            ),
            icon: Icon(
              isEditing ? Icons.save_outlined : Icons.add_rounded,
              size: 18,
            ),
            label: Text(isEditing ? 'حفظ التعديلات' : 'إنشاء التصنيف'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _saveCategory(
    BuildContext dialogContext,
    MenuCubit cubit,
    TextEditingController controller,
    MenuCategory? category,
  ) async {
    final name = controller.text.trim();
    if (name.isEmpty) {
      MotionSnackBarWarning(dialogContext, 'اكتب اسم التصنيف أولاً');
      return;
    }

    if (category == null) {
      await cubit.addCategory(name, nameAr: name);
    } else {
      await cubit.updateCategory(category.copyWith(name: name, nameAr: name));
    }
    if (!dialogContext.mounted) return;
    MotionSnackBarSuccess(
      dialogContext,
      category == null ? 'تم إنشاء التصنيف' : 'تم تحديث التصنيف',
    );
    Navigator.pop(dialogContext);
  }

  Future<void> _showItemDialog(
    BuildContext context, [
    MenuItem? item,
  ]) async {
    final cubit = context.read<MenuCubit>();
    final state = cubit.state;
    if (state.categories.isEmpty) {
      MotionSnackBarWarning(context, 'أضف تصنيفاً قبل إنشاء أول صنف');
      return;
    }

    final isEditing = item != null;
    final nameController = TextEditingController(text: item?.displayName ?? '');
    final priceController = TextEditingController(
      text: item == null ? '' : item.price.toStringAsFixed(2),
    );
    final unitController = TextEditingController(text: item?.unit ?? '');
    final descriptionController =
        TextEditingController(text: item?.description ?? '');
    var imagePath = item?.imageUrl;
    final newlyStoredImages = <String>[];
    var categoryId = state.categories.any((c) => c.id == item?.categoryId)
        ? item!.categoryId
        : (state.selectedCategoryId ?? state.categories.first.id);
    var isAvailable = item?.isAvailable ?? true;

    final result = await showDialog<_SavedImageResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => _EditorDialog(
          maxWidth: 620,
          icon:
              isEditing ? Icons.edit_note_rounded : Icons.add_business_rounded,
          title: isEditing ? 'تعديل الصنف' : 'إضافة صنف جديد',
          subtitle: isEditing
              ? 'حدّث بيانات الصنف وسعره وحالة ظهوره'
              : 'أدخل البيانات الأساسية ليصبح الصنف جاهزاً للبيع',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProductImageEditor(
                imagePath: imagePath,
                onPick: () async {
                  try {
                    final storedPath =
                        await ProductImageStorage.pickAndStoreImage();
                    if (storedPath == null || !dialogContext.mounted) return;
                    newlyStoredImages.add(storedPath);
                    setDialogState(() => imagePath = storedPath);
                  } catch (error) {
                    if (dialogContext.mounted) {
                      MotionSnackBarError(
                        dialogContext,
                        'تعذر حفظ الصورة: $error',
                      );
                    }
                  }
                },
                onRemove: imagePath == null
                    ? null
                    : () => setDialogState(() => imagePath = null),
              ),
              const SizedBox(height: AppSpacing.md),
              _ResponsiveFormRow(
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: !isEditing,
                    style: TextStyle(color: AppColors.cream),
                    decoration: _fieldDecoration(
                      label: 'اسم الصنف',
                      hint: 'مثال: كباب مشوي',
                      icon: Icons.fastfood_outlined,
                    ),
                  ),
                  TextField(
                    controller: priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: AppColors.cream),
                    decoration: _fieldDecoration(
                      label: 'سعر البيع',
                      hint: '0.00',
                      icon: Icons.payments_outlined,
                      suffix: 'ج.م',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _ResponsiveFormRow(
                children: [
                  DropdownButtonFormField<String>(
                    value: categoryId,
                    isExpanded: true,
                    dropdownColor: AppColors.charcoalMedium,
                    style: TextStyle(color: AppColors.cream),
                    decoration: _fieldDecoration(
                      label: 'التصنيف',
                      icon: Icons.category_outlined,
                    ),
                    items: state.categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(
                              category.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => categoryId = value);
                      }
                    },
                  ),
                  TextField(
                    controller: unitController,
                    style: TextStyle(color: AppColors.cream),
                    decoration: _fieldDecoration(
                      label: 'وحدة البيع (اختياري)',
                      hint: 'قطعة، كيلو، سيخ',
                      icon: Icons.scale_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 3,
                style: TextStyle(color: AppColors.cream),
                decoration: _fieldDecoration(
                  label: 'وصف مختصر (اختياري)',
                  hint: 'مكونات أو تفاصيل تساعد فريق العمل',
                  icon: Icons.notes_rounded,
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: AppSpacing.md),
                _AvailabilityPanel(
                  value: isAvailable,
                  onChanged: (value) =>
                      setDialogState(() => isAvailable = value),
                ),
              ],
            ],
          ),
          leadingAction: isEditing
              ? TextButton.icon(
                  onPressed: () async {
                    final confirmed = await _showDeleteConfirmation(
                      dialogContext,
                      title: 'حذف الصنف؟',
                      message:
                          'سيتم حذف "${item.displayName}" نهائياً من المنيو.',
                      confirmLabel: 'حذف الصنف',
                    );
                    if (!confirmed) return;
                    await cubit.deleteItem(item.id);
                    if (cubit.state.error != null) return;
                    await ProductImageStorage.deleteIfUnreferenced(
                      item.imageUrl,
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('حذف'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.grillRed,
                  ),
                )
              : null,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text.trim()) ?? 0;
                if (name.isEmpty) {
                  MotionSnackBarWarning(
                    dialogContext,
                    'اكتب اسم الصنف أولاً',
                  );
                  return;
                }
                if (price <= 0) {
                  MotionSnackBarWarning(
                    dialogContext,
                    'أدخل سعراً صحيحاً أكبر من صفر',
                  );
                  return;
                }

                final unit = unitController.text.trim();
                final description = descriptionController.text.trim();
                if (item == null) {
                  await cubit.addItem(
                    name: name,
                    nameAr: name,
                    categoryId: categoryId,
                    price: price,
                    imageUrl: imagePath,
                    unit: unit.isEmpty ? null : unit,
                    description: description.isEmpty ? null : description,
                  );
                } else {
                  await cubit.updateItem(
                    item.copyWith(
                      name: name,
                      nameAr: name,
                      categoryId: categoryId,
                      price: price,
                      imageUrl: imagePath,
                      clearImageUrl: imagePath == null,
                      unit: unit.isEmpty ? null : unit,
                      clearUnit: unit.isEmpty,
                      description: description.isEmpty ? null : description,
                      clearDescription: description.isEmpty,
                      isAvailable: isAvailable,
                    ),
                  );
                }

                if (cubit.state.error != null) return;
                if (!dialogContext.mounted) return;
                MotionSnackBarSuccess(
                  dialogContext,
                  item == null ? 'تمت إضافة الصنف' : 'تم حفظ التعديلات',
                );
                Navigator.pop(
                  dialogContext,
                  _SavedImageResult(imagePath: imagePath),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warmOrange,
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                isEditing ? Icons.save_outlined : Icons.add_rounded,
                size: 18,
              ),
              label: Text(isEditing ? 'حفظ التعديلات' : 'إضافة الصنف'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    priceController.dispose();
    unitController.dispose();
    descriptionController.dispose();

    for (final storedImage in newlyStoredImages) {
      if (result == null || storedImage != result.imagePath) {
        await ProductImageStorage.deleteIfUnreferenced(storedImage);
      }
    }
    if (result != null && item?.imageUrl != result.imagePath) {
      await ProductImageStorage.deleteIfUnreferenced(item?.imageUrl);
    }
  }

  Future<bool> _showDeleteConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.charcoalMedium,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
              side: BorderSide(color: AppColors.borderColor),
            ),
            icon: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.grillRed.withOpacity(.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.grillRed,
              ),
            ),
            title: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.creamMuted, height: 1.5),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.grillRed,
                  foregroundColor: Colors.white,
                ),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.onAddCategory,
    required this.onAddItem,
  });

  final VoidCallback onAddCategory;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: onAddCategory,
          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: const Text('تصنيف جديد'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.cream,
            side: BorderSide(color: AppColors.borderColor),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          onPressed: onAddItem,
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text('صنف جديد'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.warmOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _CompactHeaderAction extends StatelessWidget {
  const _CompactHeaderAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: 'إضافة صنف',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.warmOrange,
        foregroundColor: Colors.white,
      ),
      icon: const Icon(Icons.add_rounded),
    );
  }
}

class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({required this.state});

  final MenuState state;

  @override
  Widget build(BuildContext context) {
    final available = state.items.where((item) => item.isAvailable).length;
    final unavailable = state.items.length - available;
    final averagePrice = state.items.isEmpty
        ? 0.0
        : state.items.fold<double>(0, (sum, item) => sum + item.price) /
            state.items.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _OverviewCard(
            icon: Icons.inventory_2_outlined,
            label: 'إجمالي الأصناف',
            value: '${state.items.length}',
            color: AppColors.warmOrange,
          ),
          const SizedBox(width: AppSpacing.sm),
          _OverviewCard(
            icon: Icons.check_circle_outline_rounded,
            label: 'متاح للبيع',
            value: '$available',
            color: AppColors.successGreen,
          ),
          const SizedBox(width: AppSpacing.sm),
          _OverviewCard(
            icon: Icons.pause_circle_outline_rounded,
            label: 'غير متاح',
            value: '$unavailable',
            color: AppColors.ember,
          ),
          const SizedBox(width: AppSpacing.sm),
          _OverviewCard(
            icon: Icons.category_outlined,
            label: 'التصنيفات',
            value: '${state.categories.length}',
            color: AppColors.blueMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          _OverviewCard(
            icon: Icons.trending_up_rounded,
            label: 'متوسط السعر',
            value: '${averagePrice.toStringAsFixed(0)} ج.م',
            color: AppColors.flameLight,
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.charcoalMedium,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: AppColors.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(.035),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.creamMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

class _MenuToolbar extends StatelessWidget {
  const _MenuToolbar({
    required this.controller,
    required this.filter,
    required this.onQueryChanged,
    required this.onClear,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final _AvailabilityFilter filter;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final ValueChanged<_AvailabilityFilter> onFilterChanged;

  String get _filterLabel => switch (filter) {
        _AvailabilityFilter.all => 'كل الحالات',
        _AvailabilityFilter.available => 'المتاح فقط',
        _AvailabilityFilter.unavailable => 'غير المتاح',
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final search = TextField(
          controller: controller,
          onChanged: onQueryChanged,
          style: TextStyle(color: AppColors.cream),
          decoration: InputDecoration(
            hintText: 'ابحث بالاسم أو الوحدة أو الوصف...',
            hintStyle: TextStyle(color: AppColors.mutedColor),
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.creamMuted),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح البحث',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: AppColors.charcoalMedium,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
        );
        final availability = PopupMenuButton<_AvailabilityFilter>(
          initialValue: filter,
          onSelected: onFilterChanged,
          color: AppColors.charcoalMedium,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.borderColor),
          ),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _AvailabilityFilter.all,
              child: _FilterMenuItem(
                icon: Icons.apps_rounded,
                label: 'كل الحالات',
              ),
            ),
            PopupMenuItem(
              value: _AvailabilityFilter.available,
              child: _FilterMenuItem(
                icon: Icons.check_circle_outline_rounded,
                label: 'المتاح فقط',
                color: AppColors.successGreen,
              ),
            ),
            PopupMenuItem(
              value: _AvailabilityFilter.unavailable,
              child: _FilterMenuItem(
                icon: Icons.pause_circle_outline_rounded,
                label: 'غير المتاح',
                color: AppColors.ember,
              ),
            ),
          ],
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: filter == _AvailabilityFilter.all
                  ? AppColors.charcoalMedium
                  : AppColors.warmOrange.withOpacity(.1),
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              border: Border.all(
                color: filter == _AvailabilityFilter.all
                    ? AppColors.borderColor
                    : AppColors.warmOrange.withOpacity(.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 19,
                  color: filter == _AvailabilityFilter.all
                      ? AppColors.creamMuted
                      : AppColors.warmOrange,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _filterLabel,
                  style: TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.creamMuted,
                ),
              ],
            ),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: AppSpacing.sm),
              availability,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: AppSpacing.sm),
            availability,
          ],
        );
      },
    );
  }
}

class _FilterMenuItem extends StatelessWidget {
  const _FilterMenuItem({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color ?? AppColors.creamMuted),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: TextStyle(color: AppColors.cream)),
      ],
    );
  }
}

class _CategoryNavigation extends StatelessWidget {
  const _CategoryNavigation({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MenuCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<MenuCategory> onEdit;
  final ValueChanged<MenuCategory> onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _CategoryPill(
            label: 'كل الأصناف',
            icon: Icons.grid_view_rounded,
            selected: selectedCategoryId == null,
            onTap: () => onSelect(null),
          ),
          ...categories.map(
            (category) => _CategoryPill(
              label: category.displayName,
              icon: Icons.restaurant_rounded,
              selected: selectedCategoryId == category.id,
              onTap: () => onSelect(category.id),
              onAction: (action) {
                if (action == _CategoryAction.edit) {
                  onEdit(category);
                } else {
                  onDelete(category);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('تصنيف'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warmOrange,
                side: BorderSide(
                  color: AppColors.warmOrange.withOpacity(.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.onAction,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<_CategoryAction>? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
      child: Material(
        color: selected ? AppColors.warmOrange : AppColors.charcoalMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          side: BorderSide(
            color: selected ? AppColors.warmOrange : AppColors.borderColor,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: 14,
                  end: onAction == null ? 14 : 6,
                  top: 10,
                  bottom: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 17,
                      color: selected ? Colors.white : AppColors.creamMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.cream,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onAction != null)
              PopupMenuButton<_CategoryAction>(
                tooltip: 'خيارات التصنيف',
                padding: EdgeInsets.zero,
                iconSize: 18,
                color: AppColors.charcoalMedium,
                surfaceTintColor: Colors.transparent,
                iconColor: selected ? Colors.white : AppColors.creamMuted,
                onSelected: onAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _CategoryAction.edit,
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: AppColors.creamMuted,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'تعديل الاسم',
                          style: TextStyle(color: AppColors.cream),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: _CategoryAction.delete,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.grillRed,
                          size: 18,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'حذف التصنيف',
                          style: TextStyle(color: AppColors.grillRed),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.categoryName,
    required this.visibleCount,
    required this.totalCount,
    required this.filtered,
  });

  final String categoryName;
  final int visibleCount;
  final int totalCount;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                categoryName,
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                filtered
                    ? '$visibleCount نتيجة من أصل $totalCount'
                    : '$totalCount صنف في هذا العرض',
                style: TextStyle(
                  color: AppColors.creamMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warmOrange.withOpacity(.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$visibleCount',
            style: const TextStyle(
              color: AppColors.warmOrange,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItemCard extends StatefulWidget {
  const _MenuItemCard({
    required this.item,
    required this.categoryName,
    required this.onEdit,
    required this.onAvailabilityChanged,
  });

  final MenuItem item;
  final String categoryName;
  final VoidCallback onEdit;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  State<_MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<_MenuItemCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final statusColor =
        item.isAvailable ? AppColors.successGreen : AppColors.ember;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppColors.charcoalMedium,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: _hovered
                ? AppColors.warmOrange.withOpacity(.45)
                : AppColors.borderColor,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AppColors.warmOrange.withOpacity(.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onEdit,
            child: Stack(
              children: [
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: statusColor),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: ProductImageView(
                                source: item.imageUrl,
                                semanticLabel: 'صورة ${item.displayName}',
                                placeholder: ProductImagePlaceholder(
                                  iconSize: 24,
                                  iconColor: item.isAvailable
                                      ? AppColors.warmOrange
                                      : AppColors.mutedColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.cream,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.folder_outlined,
                                      size: 14,
                                      color: AppColors.creamMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        widget.categoryName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.creamMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'تعديل الصنف',
                            onPressed: widget.onEdit,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.edit_outlined,
                              color: AppColors.creamMuted,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: Text(
                          item.description?.trim().isNotEmpty == true
                              ? item.description!
                              : item.unit == null
                                  ? 'صنف جاهز للبيع من نقطة البيع'
                                  : 'وحدة البيع: ${item.unit}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.creamMuted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                      Divider(height: 18, color: AppColors.borderColor),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.price.toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: AppColors.warmOrange,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    'ج.م${item.unit == null ? '' : ' / ${item.unit}'}',
                                    style: TextStyle(
                                      color: AppColors.creamMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            item.isAvailable ? 'متاح' : 'متوقف',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Transform.scale(
                            scale: .82,
                            child: Switch(
                              value: item.isAvailable,
                              onChanged: widget.onAvailabilityChanged,
                              activeColor: AppColors.successGreen,
                              activeTrackColor:
                                  AppColors.successGreen.withOpacity(.3),
                              inactiveThumbColor: AppColors.creamMuted,
                              inactiveTrackColor: AppColors.charcoalLight,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _MenuLoadingState extends StatelessWidget {
  const _MenuLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.warmOrange),
          const SizedBox(height: AppSpacing.md),
          Text(
            'جاري تجهيز المنيو...',
            style: TextStyle(color: AppColors.creamMuted),
          ),
        ],
      ),
    );
  }
}

class _MenuEmptyState extends StatelessWidget {
  const _MenuEmptyState({
    required this.isFiltered,
    required this.categoryName,
    required this.onClearFilters,
    required this.onAddItem,
  });

  final bool isFiltered;
  final String? categoryName;
  final VoidCallback onClearFilters;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 470),
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
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.warmOrange.withOpacity(.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                isFiltered
                    ? Icons.search_off_rounded
                    : Icons.restaurant_menu_rounded,
                size: 34,
                color: AppColors.warmOrange,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isFiltered ? 'لا توجد نتائج مطابقة' : 'لا توجد أصناف بعد',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.cream,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isFiltered
                  ? 'جرّب تغيير عبارة البحث أو حالة التوفر.'
                  : categoryName == null
                      ? 'ابدأ بإضافة أول صنف إلى المنيو.'
                      : 'أضف أول صنف إلى تصنيف $categoryName.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.creamMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (isFiltered)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('مسح عوامل التصفية'),
              )
            else
              FilledButton.icon(
                onPressed: onAddItem,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warmOrange,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة صنف'),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditorDialog extends StatelessWidget {
  const _EditorDialog({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.actions,
    this.leadingAction,
    this.maxWidth = 460,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? leadingAction;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * .88;
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: AppColors.charcoalMedium,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
        side: BorderSide(color: AppColors.borderColor),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.warmOrange.withOpacity(.11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: AppColors.warmOrange, size: 23),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: AppColors.cream,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppColors.creamMuted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(context),
                    icon:
                        Icon(Icons.close_rounded, color: AppColors.creamMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              body,
              const SizedBox(height: AppSpacing.lg),
              Divider(color: AppColors.borderColor, height: 1),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final actionRow = Wrap(
                    alignment: WrapAlignment.end,
                    runAlignment: WrapAlignment.end,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: actions,
                  );
                  if (leadingAction == null) return actionRow;
                  if (constraints.maxWidth < 430) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: leadingAction!,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        actionRow,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      leadingAction!,
                      const Spacer(),
                      actionRow,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedImageResult {
  const _SavedImageResult({required this.imagePath});

  final String? imagePath;
}

class _ProductImageEditor extends StatelessWidget {
  const _ProductImageEditor({
    required this.imagePath,
    required this.onPick,
    required this.onRemove,
  });

  final String? imagePath;
  final Future<void> Function() onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath?.trim().isNotEmpty == true;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final preview = ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: constraints.maxWidth < 430 ? double.infinity : 150,
              height: 112,
              child: ProductImageView(
                source: imagePath,
                semanticLabel: 'معاينة صورة الصنف',
                placeholder: const ProductImagePlaceholder(iconSize: 38),
              ),
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'صورة الصنف',
                style: TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'اختر صورة واضحة. سيتم نسخها وحفظها داخل بيانات GrillPOS بأمان.',
                style: TextStyle(
                  color: AppColors.creamMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onPick,
                    style: FilledButton.styleFrom(
                      foregroundColor: AppColors.warmOrange,
                      backgroundColor: AppColors.warmOrange.withOpacity(.1),
                    ),
                    icon: Icon(
                      hasImage
                          ? Icons.sync_rounded
                          : Icons.add_photo_alternate_outlined,
                      size: 18,
                    ),
                    label: Text(hasImage ? 'استبدال الصورة' : 'اختيار صورة'),
                  ),
                  if (hasImage)
                    TextButton.icon(
                      onPressed: onRemove,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.grillRed,
                      ),
                      icon: const Icon(Icons.hide_image_outlined, size: 18),
                      label: const Text('إزالة'),
                    ),
                ],
              ),
            ],
          );

          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                preview,
                const SizedBox(height: AppSpacing.md),
                details,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              preview,
              const SizedBox(width: AppSpacing.md),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _ResponsiveFormRow extends StatelessWidget {
  const _ResponsiveFormRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1)
                const SizedBox(width: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _AvailabilityPanel extends StatelessWidget {
  const _AvailabilityPanel({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = value ? AppColors.successGreen : AppColors.ember;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              value
                  ? Icons.check_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value ? 'متاح للبيع' : 'غير متاح مؤقتاً',
                  style: TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value
                      ? 'يظهر الصنف في شاشة نقطة البيع'
                      : 'سيختفي الصنف من الأصناف المتاحة للبيع',
                  style: TextStyle(
                    color: AppColors.creamMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.successGreen,
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
  String? hint,
  String? suffix,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    labelStyle: TextStyle(color: AppColors.creamMuted),
    hintStyle: TextStyle(color: AppColors.mutedColor),
    prefixIcon: Icon(icon, color: AppColors.creamMuted, size: 20),
    filled: true,
    fillColor: AppColors.charcoalLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      borderSide: BorderSide(color: AppColors.borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      borderSide: const BorderSide(color: AppColors.warmOrange, width: 1.5),
    ),
  );
}
