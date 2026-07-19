import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/components/screen_header.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/functions/messege.dart';
import '../../../core/security/permission_guard.dart';
import '../../auth/presentation/cubit/user_cubit.dart';
import '../../settings/presentation/cubit/settings_cubit.dart';
import '../data/computer_sales_models.dart';
import 'computer_document_service.dart';
import 'cubit/computer_sales_cubit.dart';

class ComputerSalesScreen extends StatelessWidget {
  const ComputerSalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ComputerSalesCubit>()..initialize(),
      child: const _ComputerSalesView(),
    );
  }
}

class _ComputerSalesView extends StatefulWidget {
  const _ComputerSalesView();

  @override
  State<_ComputerSalesView> createState() => _ComputerSalesViewState();
}

class _ComputerSalesViewState extends State<_ComputerSalesView> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _compactDetail = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String? get _currentUser {
    try {
      return getIt<UserCubit>().currentUser.username;
    } catch (_) {
      return null;
    }
  }

  bool get _canProcessReturns {
    try {
      return PermissionGuard.can(
        getIt<UserCubit>().currentUser,
        AppPermission.processRefunds,
      );
    } catch (_) {
      return false;
    }
  }

  String get _businessName {
    try {
      final value = getIt<SettingsCubit>().currentRestaurantInfo?.name.trim();
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {
      // Printing still works with the product default when settings are absent.
    }
    return 'GrillPOS Computer Center';
  }

  void _search(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      context.read<ComputerSalesCubit>().load(search: value.trim());
    });
    setState(() {});
  }

  Future<void> _selectDocument(ComputerDocument summary) async {
    final document =
        await context.read<ComputerSalesCubit>().selectDocument(summary.id);
    if (document != null && mounted) setState(() => _compactDetail = true);
  }

  Future<void> _openQuotation([ComputerDocument? existing]) async {
    final cubit = context.read<ComputerSalesCubit>();
    var source = existing;
    if (source != null && source.lines.isEmpty) {
      source = await cubit.selectDocument(source.id);
      if (source == null || !mounted) return;
    }
    final input = await showDialog<DraftQuotationInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuotationEditorDialog(
        cubit: cubit,
        existing: source,
        currentUser: _currentUser,
      ),
    );
    if (input == null || !mounted) return;
    final saved = source == null
        ? await cubit.createQuotation(input)
        : await cubit.updateQuotation(source.id, input);
    if (saved != null && mounted) setState(() => _compactDetail = true);
  }

  Future<void> _cancelQuotation(ComputerDocument document) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => _ConfirmDialog(
            icon: LucideIcons.circleX,
            color: AppColors.errorColor,
            title: 'Cancel quotation?',
            message:
                '${document.documentNumber} will remain in history but can no longer be edited or converted.',
            confirmLabel: 'Cancel quotation',
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final success =
        await context.read<ComputerSalesCubit>().cancelQuotation(document.id);
    if (success && mounted) setState(() => _compactDetail = false);
  }

  Future<void> _convertQuotation(ComputerDocument document) async {
    final payments = await showDialog<List<PaymentInput>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConvertQuotationDialog(
        document: document,
        currentUser: _currentUser,
      ),
    );
    if (payments == null || !mounted) return;
    final sale = await context.read<ComputerSalesCubit>().convertQuotation(
          document.id,
          payments: payments,
        );
    if (sale != null && mounted) setState(() => _compactDetail = true);
  }

  Future<void> _addPayment(ComputerDocument document) async {
    final payment = await showDialog<PaymentInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(
        balance: document.balanceDue,
        currentUser: _currentUser,
      ),
    );
    if (payment == null || !mounted) return;
    await context.read<ComputerSalesCubit>().addPayment(document.id, payment);
  }

  Future<void> _createReturn(ComputerDocument document) async {
    if (!_canProcessReturns) {
      MotionSnackBarWarning(
        context,
        'Only managers can process product returns and customer refunds.',
      );
      return;
    }
    final cubit = context.read<ComputerSalesCubit>();
    final priorReturns = await cubit.loadReturns(saleId: document.id);
    if (!mounted) return;
    final returnedSerialIds = priorReturns
        .expand((item) => item.lines)
        .map((line) => line.serialId)
        .whereType<String>()
        .toSet();
    final input = await showDialog<SaleReturnInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReturnDialog(
        sale: document,
        returnedSerialIds: returnedSerialIds,
        currentUser: _currentUser,
      ),
    );
    if (input == null || !mounted) return;
    await cubit.createReturn(input);
  }

  Future<void> _printDocument(ComputerDocument document) async {
    try {
      await ComputerDocumentService.printDocument(
        document,
        businessName: _businessName,
      );
    } catch (_) {
      if (mounted) {
        MotionSnackBarError(context, 'The document could not be printed.');
      }
    }
  }

  Future<void> _shareDocument(ComputerDocument document) async {
    try {
      await ComputerDocumentService.shareDocument(
        document,
        businessName: _businessName,
      );
    } catch (_) {
      if (mounted) {
        MotionSnackBarError(context, 'The PDF could not be shared.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: AppColors.backgroundColor,
        child: SafeArea(
          child: BlocConsumer<ComputerSalesCubit, ComputerSalesState>(
            listenWhen: (previous, current) =>
                previous.error != current.error ||
                previous.notice != current.notice,
            listener: (context, state) {
              if (state.error != null) {
                AppMessage.show(
                  context,
                  state.error!,
                  type: AppMessageType.error,
                  title: 'Computer sales',
                );
              } else if (state.notice != null) {
                AppMessage.show(
                  context,
                  state.notice!,
                  type: AppMessageType.success,
                  title: 'Saved successfully',
                );
              }
            },
            builder: (context, state) {
              final cubit = context.read<ComputerSalesCubit>();
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    ScreenHeader(
                      title: 'Computer Sales',
                      subtitle:
                          'Quotations, serialized sales, payments, warranty and returns',
                      icon: LucideIcons.monitorSmartphone,
                      trailingWidget: _HeaderActions(
                        saving: state.saving,
                        onRefresh: () => cubit.initialize(),
                        onNewQuotation: () => _openQuotation(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StatsGrid(stats: state.stats),
                    const SizedBox(height: AppSpacing.md),
                    _DocumentToolbar(
                      controller: _searchController,
                      state: state,
                      onSearchChanged: _search,
                      onClearSearch: () {
                        _searchController.clear();
                        cubit.load(search: '');
                        setState(() {});
                      },
                      onTypeChanged: (value) => cubit.load(
                        type: value,
                        clearType: value == null,
                      ),
                      onStatusChanged: (value) => cubit.load(
                        status: value,
                        clearStatus: value == null,
                      ),
                      onPaymentChanged: (value) => cubit.load(
                        paymentStatus: value,
                        clearPayment: value == null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final split = constraints.maxWidth >= 1060;
                          if (!split &&
                              _compactDetail &&
                              state.selectedDocument != null) {
                            return _DocumentDetail(
                              key: ValueKey(state.selectedDocument!.id),
                              document: state.selectedDocument!,
                              cubit: cubit,
                              canReturn: _canProcessReturns,
                              compact: true,
                              onBack: () =>
                                  setState(() => _compactDetail = false),
                              onEdit: _openQuotation,
                              onCancel: _cancelQuotation,
                              onConvert: _convertQuotation,
                              onPayment: _addPayment,
                              onReturn: _createReturn,
                              onPrint: _printDocument,
                              onShare: _shareDocument,
                              onOpenLinked: (id) async {
                                await cubit.selectDocument(id);
                              },
                            );
                          }

                          final list = _DocumentList(
                            state: state,
                            selectedId: state.selectedDocument?.id,
                            onSelect: _selectDocument,
                            onRetry: () => cubit.load(),
                            onCreate: () => _openQuotation(),
                          );
                          if (!split) return list;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: list),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                flex: 7,
                                child: state.selectedDocument == null
                                    ? const _NoDocumentSelected()
                                    : _DocumentDetail(
                                        key: ValueKey(
                                            state.selectedDocument!.id),
                                        document: state.selectedDocument!,
                                        cubit: cubit,
                                        canReturn: _canProcessReturns,
                                        onEdit: _openQuotation,
                                        onCancel: _cancelQuotation,
                                        onConvert: _convertQuotation,
                                        onPayment: _addPayment,
                                        onReturn: _createReturn,
                                        onPrint: _printDocument,
                                        onShare: _shareDocument,
                                        onOpenLinked: cubit.selectDocument,
                                      ),
                              ),
                            ],
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
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.saving,
    required this.onRefresh,
    required this.onNewQuotation,
  });

  final bool saving;
  final VoidCallback onRefresh;
  final VoidCallback onNewQuotation;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Refresh documents',
          onPressed: saving ? null : onRefresh,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.refreshCw, size: 19),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          onPressed: saving ? null : onNewQuotation,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.warmOrange,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 46),
            padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 18),
          ),
          icon: const Icon(LucideIcons.plus, size: 19),
          label:
              compact ? const SizedBox.shrink() : const Text('New quotation'),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final ComputerSalesStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatData(
        'Draft quotations',
        stats.draftQuotations.toString(),
        LucideIcons.fileText,
        AppColors.blueMuted,
      ),
      _StatData(
        'Completed sales',
        stats.completedSales.toString(),
        LucideIcons.circleCheck,
        AppColors.successColor,
      ),
      _StatData(
        'Sales revenue',
        _money(stats.salesRevenue),
        LucideIcons.circleDollarSign,
        AppColors.warmOrange,
      ),
      _StatData(
        'Balance due',
        _money(stats.balanceDue),
        LucideIcons.walletCards,
        AppColors.warningColor,
      ),
      _StatData(
        'Returned value',
        _money(stats.returnedValue),
        LucideIcons.rotateCcw,
        AppColors.errorColor,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 760
                ? 3
                : 2;
        final gap = AppSpacing.sm;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _StatCard(data: item)),
          ],
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
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
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

class _DocumentToolbar extends StatelessWidget {
  const _DocumentToolbar({
    required this.controller,
    required this.state,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onPaymentChanged,
  });

  final TextEditingController controller;
  final ComputerSalesState state;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<ComputerDocumentType?> onTypeChanged;
  final ValueChanged<ComputerDocumentStatus?> onStatusChanged;
  final ValueChanged<ComputerPaymentStatus?> onPaymentChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: _cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final search = TextField(
            controller: controller,
            onChanged: onSearchChanged,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search document, customer or phone',
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClearSearch,
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
              filled: true,
              fillColor: AppColors.charcoalLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: BorderSide.none,
              ),
              isDense: true,
            ),
          );
          final filters = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _FilterDropdown<ComputerDocumentType>(
                width: 148,
                value: state.typeFilter,
                label: 'All documents',
                values: ComputerDocumentType.values,
                valueLabel: (value) => value.label,
                onChanged: onTypeChanged,
              ),
              _FilterDropdown<ComputerDocumentStatus>(
                width: 166,
                value: state.statusFilter,
                label: 'All statuses',
                values: ComputerDocumentStatus.values,
                valueLabel: (value) => value.label,
                onChanged: onStatusChanged,
              ),
              _FilterDropdown<ComputerPaymentStatus>(
                width: 176,
                value: state.paymentFilter,
                label: 'All payments',
                values: ComputerPaymentStatus.values,
                valueLabel: (value) => value.label,
                onChanged: onPaymentChanged,
              ),
            ],
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(width: AppSpacing.sm),
              filters,
            ],
          );
        },
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.width,
    required this.value,
    required this.label,
    required this.values,
    required this.valueLabel,
    required this.onChanged,
  });

  final double width;
  final T? value;
  final String label;
  final List<T> values;
  final String Function(T value) valueLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 47,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.charcoalMedium,
          icon: const Icon(LucideIcons.chevronRight, size: 16),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          items: [
            DropdownMenuItem<T?>(value: null, child: Text(label)),
            ...values.map(
              (item) => DropdownMenuItem<T?>(
                value: item,
                child: Text(valueLabel(item)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({
    required this.state,
    required this.selectedId,
    required this.onSelect,
    required this.onRetry,
    required this.onCreate,
  });

  final ComputerSalesState state;
  final String? selectedId;
  final ValueChanged<ComputerDocument> onSelect;
  final VoidCallback onRetry;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.documents.isEmpty) {
      return const _LoadingDocuments();
    }
    if (state.error != null && state.documents.isEmpty) {
      return _ErrorState(message: state.error!, onRetry: onRetry);
    }
    if (state.documents.isEmpty) {
      final filtered = state.search.isNotEmpty ||
          state.typeFilter != null ||
          state.statusFilter != null ||
          state.paymentFilter != null;
      return _EmptyDocuments(filtered: filtered, onCreate: onCreate);
    }
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales documents',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${state.documents.length} most recent results',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.loading)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderColor),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: state.documents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final document = state.documents[index];
                return _DocumentCard(
                  document: document,
                  selected: document.id == selectedId,
                  onTap: () => onSelect(document),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.selected,
    required this.onTap,
  });

  final ComputerDocument document;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeColor = document.type == ComputerDocumentType.sale
        ? AppColors.successColor
        : AppColors.blueMuted;
    final statusColor = _documentStatusColor(document.status);
    return Material(
      color: selected
          ? AppColors.warmOrange.withValues(alpha: .08)
          : AppColors.charcoalLight,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? AppColors.warmOrange.withValues(alpha: .55)
                  : AppColors.borderColor,
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      document.type == ComputerDocumentType.sale
                          ? LucideIcons.receipt
                          : LucideIcons.fileText,
                      color: typeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                document.documentNumber,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              _money(document.totalAmount),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          document.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Pill(
                    label: document.type.label,
                    color: typeColor,
                    compact: true,
                  ),
                  const SizedBox(width: 6),
                  _Pill(
                    label:
                        document.isExpired ? 'Expired' : document.status.label,
                    color:
                        document.isExpired ? AppColors.errorColor : statusColor,
                    compact: true,
                  ),
                  const Spacer(),
                  Icon(
                    LucideIcons.calendar,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _shortDate(document.createdAt),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              if (document.type == ComputerDocumentType.sale) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: document.totalAmount <= 0
                              ? 1
                              : (document.paidAmount / document.totalAmount)
                                  .clamp(0.0, 1.0),
                          backgroundColor: AppColors.borderColor,
                          color: _paymentStatusColor(document.paymentStatus),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      document.balanceDue > .005
                          ? '${_money(document.balanceDue)} due'
                          : document.paymentStatus.label,
                      style: TextStyle(
                        color: _paymentStatusColor(document.paymentStatus),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoDocumentSelected extends StatelessWidget {
  const _NoDocumentSelected();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: AppColors.blueMuted.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  LucideIcons.fileText,
                  color: AppColors.blueMuted,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a sales document',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Customer details, serial numbers, warranty, totals and payments will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDocuments extends StatelessWidget {
  const _LoadingDocuments();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ListView.separated(
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (_, __) => Container(
          height: 116,
          decoration: BoxDecoration(
            color: AppColors.charcoalLight,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: const Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateShell(
      icon: LucideIcons.triangleAlert,
      color: AppColors.errorColor,
      title: 'Could not load sales documents',
      message: message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}

class _EmptyDocuments extends StatelessWidget {
  const _EmptyDocuments({required this.filtered, required this.onCreate});

  final bool filtered;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _StateShell(
      icon: filtered ? LucideIcons.search : LucideIcons.receipt,
      color: filtered ? AppColors.blueMuted : AppColors.warmOrange,
      title: filtered ? 'No matching documents' : 'Create your first quotation',
      message: filtered
          ? 'Try a different search term or remove one of the filters.'
          : 'Build a professional computer quotation, reserve serial choices and convert it into a sale.',
      actionLabel: filtered ? null : 'New quotation',
      onAction: filtered ? null : onCreate,
    );
  }
}

class _StateShell extends StatelessWidget {
  const _StateShell({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(icon, color: color, size: 29),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 410),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(LucideIcons.arrowRight, size: 17),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentDetail extends StatefulWidget {
  const _DocumentDetail({
    super.key,
    required this.document,
    required this.cubit,
    required this.canReturn,
    required this.onEdit,
    required this.onCancel,
    required this.onConvert,
    required this.onPayment,
    required this.onReturn,
    required this.onPrint,
    required this.onShare,
    required this.onOpenLinked,
    this.compact = false,
    this.onBack,
  });

  final ComputerDocument document;
  final ComputerSalesCubit cubit;
  final bool canReturn;
  final bool compact;
  final VoidCallback? onBack;
  final void Function(ComputerDocument document) onEdit;
  final void Function(ComputerDocument document) onCancel;
  final void Function(ComputerDocument document) onConvert;
  final void Function(ComputerDocument document) onPayment;
  final void Function(ComputerDocument document) onReturn;
  final void Function(ComputerDocument document) onPrint;
  final void Function(ComputerDocument document) onShare;
  final void Function(String documentId) onOpenLinked;

  @override
  State<_DocumentDetail> createState() => _DocumentDetailState();
}

class _DocumentDetailState extends State<_DocumentDetail> {
  late Future<List<ComputerReturn>> _returns;

  @override
  void initState() {
    super.initState();
    _loadReturns();
  }

  @override
  void didUpdateWidget(covariant _DocumentDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id ||
        oldWidget.document.updatedAt != widget.document.updatedAt) {
      _loadReturns();
    }
  }

  void _loadReturns() {
    _returns = widget.document.type == ComputerDocumentType.sale
        ? widget.cubit.loadReturns(saleId: widget.document.id)
        : Future.value(const []);
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final isDraft = document.type == ComputerDocumentType.quotation &&
        document.status == ComputerDocumentStatus.draft;
    final isSale = document.type == ComputerDocumentType.sale;
    final hasReturnable = document.lines.any(
      (line) => line.returnableQuantity > .005,
    );
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.compact) ...[
                  IconButton.filledTonal(
                    tooltip: 'Back to documents',
                    onPressed: widget.onBack,
                    icon: const Icon(LucideIcons.chevronLeft, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        (isSale ? AppColors.successColor : AppColors.blueMuted)
                            .withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    isSale ? LucideIcons.receipt : LucideIcons.fileText,
                    color:
                        isSale ? AppColors.successColor : AppColors.blueMuted,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            document.documentNumber,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          _Pill(
                            label: document.type.label,
                            color: isSale
                                ? AppColors.successColor
                                : AppColors.blueMuted,
                            compact: true,
                          ),
                          _Pill(
                            label: document.isExpired
                                ? 'Expired'
                                : document.status.label,
                            color: document.isExpired
                                ? AppColors.errorColor
                                : _documentStatusColor(document.status),
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${document.customerName}  •  ${_longDate(document.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Document options',
                  color: AppColors.charcoalMedium,
                  onSelected: (value) {
                    if (value == 'print') widget.onPrint(document);
                    if (value == 'share') widget.onShare(document);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'print',
                      child: _MenuOption(
                        icon: LucideIcons.printer,
                        label: 'Print document',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: _MenuOption(
                        icon: LucideIcons.fileText,
                        label: 'Share PDF',
                      ),
                    ),
                  ],
                  icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderColor),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CustomerSummary(document: document),
                  if (document.sourceQuotationId != null ||
                      document.convertedSaleId != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _LinkedDocumentBanner(
                      document: document,
                      onOpen: widget.onOpenLinked,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _DetailSection(
                    title: 'Products & warranty',
                    subtitle:
                        '${document.lines.length} ${document.lines.length == 1 ? 'line' : 'lines'}',
                    icon: LucideIcons.package,
                    child: Column(
                      children: [
                        for (var index = 0;
                            index < document.lines.length;
                            index++) ...[
                          if (index > 0)
                            Divider(height: 1, color: AppColors.borderColor),
                          _DocumentLineTile(line: document.lines[index]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 660;
                      final notes = _NotesCard(document: document);
                      final totals = _TotalsCard(document: document);
                      if (!wide) {
                        return Column(
                          children: [
                            totals,
                            const SizedBox(height: AppSpacing.md),
                            notes,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: notes),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(width: 290, child: totals),
                        ],
                      );
                    },
                  ),
                  if (isSale) ...[
                    const SizedBox(height: AppSpacing.md),
                    _PaymentsSection(document: document),
                    FutureBuilder<List<ComputerReturn>>(
                      future: _returns,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.md),
                            child: LinearProgressIndicator(minHeight: 2),
                          );
                        }
                        final returns = snapshot.data ?? const [];
                        if (returns.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: _ReturnsSection(returns: returns),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 72),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.borderColor),
          _DocumentActions(
            document: document,
            canReturn: widget.canReturn,
            hasReturnable: hasReturnable,
            onEdit: isDraft ? () => widget.onEdit(document) : null,
            onCancel: isDraft ? () => widget.onCancel(document) : null,
            onConvert: isDraft && !document.isExpired
                ? () => widget.onConvert(document)
                : null,
            onPayment: isSale && document.balanceDue > .005
                ? () => widget.onPayment(document)
                : null,
            onReturn: isSale && widget.canReturn && hasReturnable
                ? () => widget.onReturn(document)
                : null,
          ),
        ],
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  const _MenuOption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

class _CustomerSummary extends StatelessWidget {
  const _CustomerSummary({required this.document});

  final ComputerDocument document;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final items = [
            _InfoData(
              'Customer',
              document.customerName,
              LucideIcons.user,
            ),
            _InfoData(
              'Phone',
              document.customerPhone.isEmpty
                  ? 'Not provided'
                  : document.customerPhone,
              LucideIcons.phone,
            ),
            _InfoData(
              document.type == ComputerDocumentType.quotation
                  ? 'Valid until'
                  : 'Completed',
              document.type == ComputerDocumentType.quotation
                  ? (document.expiryDate == null
                      ? 'No expiry'
                      : _longDate(document.expiryDate!))
                  : (document.completedAt == null
                      ? _longDate(document.createdAt)
                      : _longDate(document.completedAt!)),
              LucideIcons.calendar,
            ),
          ];
          final narrow = constraints.maxWidth < 560;
          if (narrow) {
            return Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  _InfoItem(data: items[index]),
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0)
                  Container(
                    width: 1,
                    height: 35,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: AppColors.borderColor,
                  ),
                Expanded(child: _InfoItem(data: items[index])),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.data});

  final _InfoData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(data.icon, color: AppColors.warmOrange, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label.toUpperCase(),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                  letterSpacing: .7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkedDocumentBanner extends StatelessWidget {
  const _LinkedDocumentBanner({required this.document, required this.onOpen});

  final ComputerDocument document;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    final target = document.convertedSaleId ?? document.sourceQuotationId;
    final fromQuote = document.sourceQuotationId != null;
    return Material(
      color: AppColors.blueMuted.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: target == null ? null : () => onOpen(target),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.blueMuted.withValues(alpha: .24),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.fileText,
                color: AppColors.blueMuted,
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  fromQuote
                      ? 'Created from a quotation — open the source document'
                      : 'Converted successfully — open the linked sale',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: AppColors.blueMuted,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: AppColors.warmOrange, size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderColor),
          child,
        ],
      ),
    );
  }
}

class _DocumentLineTile extends StatelessWidget {
  const _DocumentLineTile({required this.line});

  final ComputerDocumentLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.productName,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              if (line.sku?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 3),
                Text(
                  'SKU ${line.sku}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
              if (line.serials.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final serial in line.serials)
                      _MiniTag(
                        icon: LucideIcons.scanLine,
                        text: serial.serialNumber,
                        color: AppColors.blueMuted,
                      ),
                  ],
                ),
              ],
              if (line.warrantyMonths > 0) ...[
                const SizedBox(height: 7),
                _MiniTag(
                  icon: LucideIcons.shieldCheck,
                  text: line.warrantyExpiry == null
                      ? '${line.warrantyMonths} months warranty'
                      : '${line.warrantyMonths} months • until ${_shortDate(line.warrantyExpiry!)}',
                  color: AppColors.successColor,
                ),
              ],
            ],
          );
          final amounts = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(line.lineSubtotal),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_quantity(line.quantity)} × ${_money(line.unitPrice)}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                ),
              ),
              if (line.returnedQuantity > .005) ...[
                const SizedBox(height: 7),
                _Pill(
                  label: '${_quantity(line.returnedQuantity)} returned',
                  color: AppColors.errorColor,
                  compact: true,
                ),
              ],
            ],
          );
          if (constraints.maxWidth < 470) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: amounts),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 12),
              amounts,
            ],
          );
        },
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.document});

  final ComputerDocument document;

  @override
  Widget build(BuildContext context) {
    final hasNotes = document.notes?.trim().isNotEmpty ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.stickyNote,
                color: AppColors.blueMuted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Document notes',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasNotes ? document.notes!.trim() : 'No notes were added.',
            style: TextStyle(
              color: hasNotes ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 11.5,
              height: 1.45,
              fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.document});

  final ComputerDocument document;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          _TotalRow('Subtotal', document.subtotal),
          if (document.discountAmount > .005)
            _TotalRow('Discount', -document.discountAmount),
          if (document.taxAmount > .005)
            _TotalRow(
              'Tax (${document.taxRate.toStringAsFixed(1)}%)',
              document.taxAmount,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppColors.borderColor),
          ),
          _TotalRow('Total', document.totalAmount, strong: true),
          if (document.type == ComputerDocumentType.sale) ...[
            const SizedBox(height: 7),
            _TotalRow(
              'Paid',
              document.paidAmount,
              color: AppColors.successColor,
            ),
            if (document.refundedAmount > .005)
              _TotalRow(
                'Refunded',
                -document.refundedAmount,
                color: AppColors.errorColor,
              ),
            _TotalRow(
              'Balance due',
              document.balanceDue,
              strong: document.balanceDue > .005,
              color: document.balanceDue > .005
                  ? AppColors.warningColor
                  : AppColors.successColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.strong = false, this.color});

  final String label;
  final double value;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? (strong ? AppColors.textPrimary : AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: strong ? 13 : 11,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          Text(
            value < 0 ? '-${_money(value.abs())}' : _money(value),
            style: TextStyle(
              color: effectiveColor,
              fontSize: strong ? 14 : 11.5,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection({required this.document});

  final ComputerDocument document;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: 'Payment history',
      subtitle: document.payments.isEmpty
          ? document.paymentStatus.label
          : '${document.payments.length} ${document.payments.length == 1 ? 'payment' : 'payments'}',
      icon: LucideIcons.walletCards,
      child: document.payments.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No payments have been recorded for this sale.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          : Column(
              children: [
                for (var index = 0;
                    index < document.payments.length;
                    index++) ...[
                  if (index > 0)
                    Divider(height: 1, color: AppColors.borderColor),
                  _PaymentTile(payment: document.payments[index]),
                ],
              ],
            ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final ComputerPayment payment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.successColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.circleCheck,
              color: AppColors.successColor,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.method.label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _longDateTime(payment.createdAt),
                    if (payment.referenceNumber?.trim().isNotEmpty ?? false)
                      'Ref ${payment.referenceNumber}',
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _money(payment.amount),
            style: const TextStyle(
              color: AppColors.successColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnsSection extends StatelessWidget {
  const _ReturnsSection({required this.returns});

  final List<ComputerReturn> returns;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: 'Return history',
      subtitle:
          '${returns.length} ${returns.length == 1 ? 'return' : 'returns'}',
      icon: LucideIcons.rotateCcw,
      child: Column(
        children: [
          for (var index = 0; index < returns.length; index++) ...[
            if (index > 0) Divider(height: 1, color: AppColors.borderColor),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          returns[index].returnNumber,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_longDateTime(returns[index].createdAt)} • ${returns[index].lines.map((line) => line.productName).toSet().join(', ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        if (returns[index].reason?.trim().isNotEmpty ??
                            false) ...[
                          const SizedBox(height: 4),
                          Text(
                            returns[index].reason!,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _money(returns[index].refundAmount),
                    style: const TextStyle(
                      color: AppColors.errorColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentActions extends StatelessWidget {
  const _DocumentActions({
    required this.document,
    required this.canReturn,
    required this.hasReturnable,
    this.onEdit,
    this.onCancel,
    this.onConvert,
    this.onPayment,
    this.onReturn,
  });

  final ComputerDocument document;
  final bool canReturn;
  final bool hasReturnable;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onConvert;
  final VoidCallback? onPayment;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (onCancel != null)
        _ActionButton(
          label: 'Cancel',
          icon: LucideIcons.circleX,
          onPressed: onCancel!,
          color: AppColors.errorColor,
          outlined: true,
        ),
      if (onEdit != null)
        _ActionButton(
          label: 'Edit quote',
          icon: LucideIcons.edit3,
          onPressed: onEdit!,
          color: AppColors.blueMuted,
          outlined: true,
        ),
      if (onReturn != null)
        _ActionButton(
          label: 'Return items',
          icon: LucideIcons.rotateCcw,
          onPressed: onReturn!,
          color: AppColors.errorColor,
          outlined: true,
        ),
      if (document.type == ComputerDocumentType.sale &&
          hasReturnable &&
          !canReturn)
        Tooltip(
          message: 'Manager authorization is required for returns',
          child: _ActionButton(
            label: 'Manager return',
            icon: LucideIcons.shieldCheck,
            onPressed: null,
            color: AppColors.textSecondary,
            outlined: true,
          ),
        ),
      if (onPayment != null)
        _ActionButton(
          label: 'Add payment',
          icon: LucideIcons.walletCards,
          onPressed: onPayment!,
          color: AppColors.successColor,
          outlined: true,
        ),
      if (onConvert != null)
        _ActionButton(
          label: 'Convert to sale',
          icon: LucideIcons.arrowRight,
          onPressed: onConvert!,
          color: AppColors.warmOrange,
        ),
    ];
    if (actions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Icon(
              LucideIcons.circleCheck,
              color: _documentStatusColor(document.status),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This document has no pending actions.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            actions[index],
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: .42)),
          minimumSize: const Size(0, 42),
        ),
        icon: Icon(icon, size: 17),
        label: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 42),
      ),
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _QuotationEditorDialog extends StatefulWidget {
  const _QuotationEditorDialog({
    required this.cubit,
    required this.currentUser,
    this.existing,
  });

  final ComputerSalesCubit cubit;
  final ComputerDocument? existing;
  final String? currentUser;

  @override
  State<_QuotationEditorDialog> createState() => _QuotationEditorDialogState();
}

class _QuotationEditorDialogState extends State<_QuotationEditorDialog> {
  final _customerSearch = TextEditingController();
  final _productSearch = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _tax = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final List<_QuoteLineEditor> _lines = [];
  final Map<String, List<AvailableSerial>> _serials = {};
  final Set<String> _loadingSerials = {};
  Timer? _customerDebounce;
  Timer? _productDebounce;
  String? _customerId;
  late DateTime _expiry;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _customerId = existing?.customerId;
    _expiry =
        existing?.expiryDate ?? DateTime.now().add(const Duration(days: 14));
    if (existing != null) {
      _discount.text = existing.discountAmount.toStringAsFixed(2);
      _tax.text = existing.taxRate.toStringAsFixed(2);
      _notes.text = existing.notes ?? '';
      for (final source in existing.lines) {
        final product = _resolveProduct(source);
        final line = _QuoteLineEditor(
          product: product,
          quantity: source.quantity,
          unitPrice: source.unitPrice,
          warrantyMonths: source.warrantyMonths,
        )..serialIds.addAll(source.serials.map((serial) => serial.id));
        _lines.add(line);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final line in _lines.where((line) => line.product.trackSerials)) {
          _loadSerials(line.product);
        }
      });
    }
  }

  SaleableProduct _resolveProduct(ComputerDocumentLine line) {
    for (final product in widget.cubit.state.products) {
      if (product.id == line.productId) return product;
    }
    return SaleableProduct(
      id: line.productId,
      name: line.productName,
      sku: line.sku,
      price: line.unitPrice,
      cost: line.unitCost,
      stock: math.max(line.quantity, 0),
      trackSerials: line.trackSerials,
      warrantyMonths: line.warrantyMonths,
    );
  }

  @override
  void dispose() {
    _customerDebounce?.cancel();
    _productDebounce?.cancel();
    _customerSearch.dispose();
    _productSearch.dispose();
    _discount.dispose();
    _tax.dispose();
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSerials(SaleableProduct product) async {
    if (_serials.containsKey(product.id) ||
        _loadingSerials.contains(product.id)) {
      return;
    }
    setState(() => _loadingSerials.add(product.id));
    final values = await widget.cubit.getAvailableSerials(
      product.id,
      forQuotationId: widget.existing?.id,
    );
    if (!mounted) return;
    setState(() {
      _loadingSerials.remove(product.id);
      _serials[product.id] = values;
    });
  }

  Future<void> _addProduct(SaleableProduct product) async {
    if (_lines.any((line) => line.product.id == product.id)) {
      MotionSnackBarInfo(context, 'This product is already in the quotation.');
      return;
    }
    if (product.stock <= .005) {
      MotionSnackBarWarning(context, '${product.name} is out of stock.');
      return;
    }
    if (product.trackSerials) {
      await _loadSerials(product);
      if (!mounted) return;
      if ((_serials[product.id] ?? const []).isEmpty) {
        MotionSnackBarWarning(
          context,
          '${product.name} has no available serial numbers.',
        );
        return;
      }
    }
    setState(() {
      _lines.add(
        _QuoteLineEditor(
          product: product,
          quantity: 1,
          unitPrice: product.price,
          warrantyMonths: product.warrantyMonths,
        ),
      );
    });
  }

  void _removeLine(_QuoteLineEditor line) {
    setState(() => _lines.remove(line));
    line.dispose();
  }

  Future<void> _chooseSerials(_QuoteLineEditor line) async {
    await _loadSerials(line.product);
    if (!mounted) return;
    final quantity = double.tryParse(line.quantity.text) ?? 0;
    if (quantity <= 0 || quantity != quantity.roundToDouble()) {
      MotionSnackBarWarning(
        context,
        'Enter a valid whole-number quantity before choosing serials.',
      );
      return;
    }
    final required = quantity.toInt();
    final available = _serials[line.product.id] ?? const [];
    if (available.length < required) {
      MotionSnackBarWarning(
        context,
        'Only ${available.length} serial numbers are currently available.',
      );
      return;
    }
    final selected = await showDialog<Set<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SerialPickerDialog(
        productName: line.product.name,
        serials: available,
        selected: line.serialIds,
        requiredCount: required,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      line.serialIds
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _newCustomer() async {
    final input = await showDialog<NewComputerCustomerInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CustomerDialog(),
    );
    if (input == null || !mounted) return;
    final customer = await widget.cubit.createCustomer(input);
    if (customer != null && mounted) {
      setState(() => _customerId = customer.id);
    }
  }

  Future<void> _pickExpiry() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _expiry.isBefore(DateTime.now()) ? DateTime.now() : _expiry,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Quotation expiry date',
    );
    if (value != null && mounted) setState(() => _expiry = value);
  }

  double get _subtotal => _lines.fold<double>(0, (sum, line) {
        final quantity = double.tryParse(line.quantity.text) ?? 0;
        final price = double.tryParse(line.unitPrice.text) ?? 0;
        return sum + quantity * price;
      });

  double get _discountValue => double.tryParse(_discount.text) ?? 0;
  double get _taxRate => double.tryParse(_tax.text) ?? 0;
  double get _taxValue =>
      math.max(0, _subtotal - _discountValue) * _taxRate / 100;
  double get _total => math.max(0, _subtotal - _discountValue) + _taxValue;

  void _submit() {
    if (_customerId == null) {
      MotionSnackBarWarning(context, 'Select or create a customer.');
      return;
    }
    if (_lines.isEmpty) {
      MotionSnackBarWarning(context, 'Add at least one product.');
      return;
    }
    final inputs = <QuotationLineInput>[];
    for (final line in _lines) {
      final quantity = double.tryParse(line.quantity.text);
      final price = double.tryParse(line.unitPrice.text);
      final warranty = int.tryParse(line.warranty.text);
      if (quantity == null || quantity <= 0) {
        MotionSnackBarWarning(
          context,
          'Enter a positive quantity for ${line.product.name}.',
        );
        return;
      }
      if (quantity > line.product.stock + .005) {
        MotionSnackBarWarning(
          context,
          '${line.product.name} has only ${_quantity(line.product.stock)} in stock.',
        );
        return;
      }
      if (price == null || price < 0) {
        MotionSnackBarWarning(
          context,
          'Enter a valid price for ${line.product.name}.',
        );
        return;
      }
      if (warranty == null || warranty < 0) {
        MotionSnackBarWarning(
          context,
          'Enter valid warranty months for ${line.product.name}.',
        );
        return;
      }
      if (line.product.trackSerials) {
        if (quantity != quantity.roundToDouble()) {
          MotionSnackBarWarning(
            context,
            'Serialized products require whole-number quantities.',
          );
          return;
        }
        if (line.serialIds.length != quantity.toInt()) {
          MotionSnackBarWarning(
            context,
            'Choose one serial number for each ${line.product.name}.',
          );
          return;
        }
      }
      inputs.add(
        QuotationLineInput(
          productId: line.product.id,
          quantity: quantity,
          unitPrice: price,
          warrantyMonths: warranty,
          serialIds: line.serialIds.toList(growable: false),
        ),
      );
    }
    if (_discountValue < 0 || _discountValue > _subtotal + .005) {
      MotionSnackBarWarning(
        context,
        'Discount must be between zero and the subtotal.',
      );
      return;
    }
    if (_taxRate < 0 || _taxRate > 100) {
      MotionSnackBarWarning(context, 'Tax rate must be between 0 and 100%.');
      return;
    }
    Navigator.pop(
      context,
      DraftQuotationInput(
        customerId: _customerId!,
        lines: inputs,
        expiryDate: _expiry,
        discountAmount: _discountValue,
        taxRate: _taxRate,
        notes: _notes.text.trim(),
        createdBy: widget.currentUser,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ComputerSalesCubit, ComputerSalesState>(
      bloc: widget.cubit,
      builder: (context, state) {
        return _SalesDialogShell(
          title: _editing ? 'Edit draft quotation' : 'New computer quotation',
          subtitle: _editing
              ? 'Update customer, products, serials and commercial terms.'
              : 'Build a complete quote ready to convert into a serialized sale.',
          icon: _editing ? LucideIcons.edit3 : LucideIcons.fileText,
          actionLabel: _editing ? 'Save changes' : 'Create quotation',
          onSubmit: _submit,
          maxWidth: 1180,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              final catalog = _buildCatalog(state);
              final order = _buildQuotation(state);
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    catalog,
                    const SizedBox(height: AppSpacing.md),
                    order,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 350, child: catalog),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: order),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCatalog(ComputerSalesState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          title: 'Customer',
          icon: LucideIcons.user,
          trailing: TextButton.icon(
            onPressed: state.saving ? null : _newCustomer,
            icon: const Icon(LucideIcons.plus, size: 15),
            label: const Text('New'),
          ),
          child: Column(
            children: [
              TextField(
                controller: _customerSearch,
                onChanged: (value) {
                  _customerDebounce?.cancel();
                  _customerDebounce =
                      Timer(const Duration(milliseconds: 260), () {
                    widget.cubit.loadCustomers(search: value.trim());
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search name or phone',
                  prefixIcon: Icon(LucideIcons.search, size: 17),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              if (state.customers.isEmpty)
                _InlineEmpty(
                  text: 'No customers found. Create a customer to continue.',
                  action: _newCustomer,
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final customer = state.customers[index];
                      final selected = customer.id == _customerId;
                      return _SelectionTile(
                        title: customer.name,
                        subtitle: customer.phone,
                        selected: selected,
                        onTap: () => setState(() => _customerId = customer.id),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Panel(
          title: 'Product catalog',
          icon: LucideIcons.package,
          child: Column(
            children: [
              TextField(
                controller: _productSearch,
                onChanged: (value) {
                  _productDebounce?.cancel();
                  _productDebounce =
                      Timer(const Duration(milliseconds: 260), () {
                    widget.cubit.loadProducts(search: value.trim());
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search product, SKU or barcode',
                  prefixIcon: Icon(LucideIcons.search, size: 17),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              if (state.products.isEmpty)
                const _InlineEmpty(
                  text: 'No saleable inventory products match this search.',
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 290),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final product = state.products[index];
                      return _ProductPickerTile(
                        product: product,
                        added: _lines.any(
                          (line) => line.product.id == product.id,
                        ),
                        onTap: () => _addProduct(product),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuotation(ComputerSalesState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          title: 'Quotation products',
          icon: LucideIcons.shoppingCart,
          trailing: _Pill(
            label: '${_lines.length} ${_lines.length == 1 ? 'item' : 'items'}',
            color: AppColors.warmOrange,
            compact: true,
          ),
          child: _lines.isEmpty
              ? const _InlineEmpty(
                  text:
                      'Choose products from the catalog to build this quotation.',
                )
              : Column(
                  children: [
                    for (var index = 0; index < _lines.length; index++) ...[
                      if (index > 0) const SizedBox(height: 8),
                      _QuotationLineCard(
                        line: _lines[index],
                        availableSerials:
                            _serials[_lines[index].product.id] ?? const [],
                        loadingSerials:
                            _loadingSerials.contains(_lines[index].product.id),
                        onChanged: () => setState(() {}),
                        onRemove: () => _removeLine(_lines[index]),
                        onChooseSerials: () => _chooseSerials(_lines[index]),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Panel(
          title: 'Commercial terms',
          icon: LucideIcons.fileText,
          child: Column(
            children: [
              _ResponsiveFields(
                children: [
                  InkWell(
                    onTap: _pickExpiry,
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Valid until',
                        suffixIcon: Icon(LucideIcons.calendar, size: 18),
                      ),
                      child: Text(
                        _longDate(_expiry),
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  _AppField(
                    controller: _discount,
                    label: 'Discount amount',
                    number: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  _AppField(
                    controller: _tax,
                    label: 'Tax rate %',
                    number: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              _AppField(
                controller: _notes,
                label: 'Quotation notes',
                hint: 'Delivery, payment, warranty or customer notes',
                maxLines: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _QuotationTotal(
          subtotal: _subtotal,
          discount: _discountValue,
          tax: _taxValue,
          total: _total,
        ),
      ],
    );
  }
}

class _QuoteLineEditor {
  _QuoteLineEditor({
    required this.product,
    required double quantity,
    required double unitPrice,
    required int warrantyMonths,
  })  : quantity = TextEditingController(text: _quantity(quantity)),
        unitPrice = TextEditingController(text: unitPrice.toStringAsFixed(2)),
        warranty = TextEditingController(text: warrantyMonths.toString());

  final SaleableProduct product;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController warranty;
  final Set<String> serialIds = {};

  void dispose() {
    quantity.dispose();
    unitPrice.dispose();
    warranty.dispose();
  }
}

class _QuotationLineCard extends StatelessWidget {
  const _QuotationLineCard({
    required this.line,
    required this.availableSerials,
    required this.loadingSerials,
    required this.onChanged,
    required this.onRemove,
    required this.onChooseSerials,
  });

  final _QuoteLineEditor line;
  final List<AvailableSerial> availableSerials;
  final bool loadingSerials;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onChooseSerials;

  void _changeQuantity(double delta) {
    final current = double.tryParse(line.quantity.text) ?? 0;
    final maximum = line.product.trackSerials
        ? math.min(line.product.stock, availableSerials.length.toDouble())
        : line.product.stock;
    final next =
        (current + delta).clamp(1.0, math.max(1.0, maximum)).toDouble();
    line.quantity.text = _quantity(next);
    if (line.product.trackSerials && line.serialIds.length > next.toInt()) {
      final keep = line.serialIds.take(next.toInt()).toSet();
      line.serialIds
        ..clear()
        ..addAll(keep);
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final quantity = double.tryParse(line.quantity.text) ?? 0;
    final price = double.tryParse(line.unitPrice.text) ?? 0;
    final serialComplete = !line.product.trackSerials ||
        (quantity == quantity.roundToDouble() &&
            line.serialIds.length == quantity.toInt());
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.charcoalMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: serialComplete
              ? AppColors.borderColor
              : AppColors.warningColor.withValues(alpha: .45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.blueMuted.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  line.product.trackSerials
                      ? LucideIcons.scanLine
                      : LucideIcons.package,
                  color: AppColors.blueMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_quantity(line.product.stock)} available${line.product.sku?.isNotEmpty ?? false ? ' • ${line.product.sku}' : ''}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove product',
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  LucideIcons.x,
                  color: AppColors.errorColor,
                  size: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => _changeQuantity(-1),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.fileMinus, size: 15),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: line.quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        onChanged: (_) => onChanged(),
                        decoration: const InputDecoration(
                          labelText: 'Qty',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    IconButton.filledTonal(
                      onPressed: () => _changeQuantity(1),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.plus, size: 15),
                    ),
                  ],
                ),
                SizedBox(
                  width: 130,
                  child: _AppField(
                    controller: line.unitPrice,
                    label: 'Unit price',
                    number: true,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                SizedBox(
                  width: 122,
                  child: _AppField(
                    controller: line.warranty,
                    label: 'Warranty months',
                    number: true,
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: fields,
              );
            },
          ),
          if (line.product.trackSerials) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: loadingSerials ? null : onChooseSerials,
              style: OutlinedButton.styleFrom(
                foregroundColor: serialComplete
                    ? AppColors.successColor
                    : AppColors.warningColor,
                side: BorderSide(
                  color: (serialComplete
                          ? AppColors.successColor
                          : AppColors.warningColor)
                      .withValues(alpha: .45),
                ),
                alignment: Alignment.centerLeft,
              ),
              icon: loadingSerials
                  ? const SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.scanLine, size: 16),
              label: Text(
                serialComplete
                    ? '${line.serialIds.length} serial ${line.serialIds.length == 1 ? 'number' : 'numbers'} selected'
                    : 'Choose ${quantity > 0 && quantity == quantity.roundToDouble() ? quantity.toInt() : '-'} serial numbers',
              ),
            ),
          ],
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Line total  ${_money(quantity * price)}',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotationTotal extends StatelessWidget {
  const _QuotationTotal({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  final double subtotal;
  final double discount;
  final double tax;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warmOrange.withValues(alpha: .12),
            AppColors.ember.withValues(alpha: .05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.warmOrange.withValues(alpha: .28),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _AmountMetric('Subtotal', subtotal)),
          Expanded(child: _AmountMetric('Discount', discount)),
          Expanded(child: _AmountMetric('Tax', tax)),
          Container(width: 1, height: 34, color: AppColors.borderColor),
          Expanded(
            child: _AmountMetric(
              'Quotation total',
              total,
              strong: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountMetric extends StatelessWidget {
  const _AmountMetric(this.label, this.value, {this.strong = false});

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _money(value),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: strong ? AppColors.warmOrange : AppColors.textPrimary,
            fontSize: strong ? 14 : 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SerialPickerDialog extends StatefulWidget {
  const _SerialPickerDialog({
    required this.productName,
    required this.serials,
    required this.selected,
    required this.requiredCount,
  });

  final String productName;
  final List<AvailableSerial> serials;
  final Set<String> selected;
  final int requiredCount;

  @override
  State<_SerialPickerDialog> createState() => _SerialPickerDialogState();
}

class _SerialPickerDialogState extends State<_SerialPickerDialog> {
  final _search = TextEditingController();
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final availableIds = widget.serials.map((serial) => serial.id).toSet();
    _selected = widget.selected.intersection(availableIds);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = _search.text.trim().toLowerCase();
    final visible = widget.serials
        .where((serial) => serial.serialNumber.toLowerCase().contains(term))
        .toList(growable: false);
    return _SalesDialogShell(
      title: 'Select serial numbers',
      subtitle:
          '${widget.productName} • choose exactly ${widget.requiredCount}',
      icon: LucideIcons.scanLine,
      actionLabel: 'Use selected serials',
      maxWidth: 590,
      onSubmit: () {
        if (_selected.length != widget.requiredCount) {
          MotionSnackBarWarning(
            context,
            'Select exactly ${widget.requiredCount} serial numbers.',
          );
          return;
        }
        Navigator.pop(context, _selected);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_selected.length == widget.requiredCount
                      ? AppColors.successColor
                      : AppColors.warningColor)
                  .withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_selected.length == widget.requiredCount
                        ? AppColors.successColor
                        : AppColors.warningColor)
                    .withValues(alpha: .25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selected.length == widget.requiredCount
                      ? LucideIcons.circleCheck
                      : LucideIcons.circleAlert,
                  size: 18,
                  color: _selected.length == widget.requiredCount
                      ? AppColors.successColor
                      : AppColors.warningColor,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${_selected.length} of ${widget.requiredCount} selected',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search serial number',
              prefixIcon: Icon(LucideIcons.search, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 370),
            child: visible.isEmpty
                ? const _InlineEmpty(
                    text: 'No serial numbers match the search.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final serial = visible[index];
                      final selected = _selected.contains(serial.id);
                      return _SelectionTile(
                        title: serial.serialNumber,
                        subtitle:
                            'Unit cost ${_money(serial.purchaseCost)} • available',
                        selected: selected,
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selected.remove(serial.id);
                            } else if (_selected.length <
                                widget.requiredCount) {
                              _selected.add(serial.id);
                            } else {
                              MotionSnackBarWarning(
                                context,
                                'Only ${widget.requiredCount} serial numbers are required.',
                              );
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog();

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_name, _phone, _email, _address, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      NewComputerCustomerInput(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SalesDialogShell(
      title: 'New computer-sales customer',
      subtitle:
          'Create a reusable customer profile for quotations and warranty.',
      icon: LucideIcons.userPlus,
      actionLabel: 'Create customer',
      onSubmit: _submit,
      maxWidth: 650,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _ResponsiveFields(
              children: [
                _AppField(
                  controller: _name,
                  label: 'Customer name *',
                  validator: _required,
                ),
                _AppField(
                  controller: _phone,
                  label: 'Phone number *',
                  validator: _required,
                ),
              ],
            ),
            _ResponsiveFields(
              children: [
                _AppField(controller: _email, label: 'Email'),
                _AppField(controller: _address, label: 'Address'),
              ],
            ),
            _AppField(
              controller: _notes,
              label: 'Customer notes',
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 9, 9, 9),
            child: Row(
              children: [
                Icon(icon, color: AppColors.warmOrange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderColor),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.warmOrange.withValues(alpha: .09)
          : AppColors.charcoalMedium,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.warmOrange.withValues(alpha: .45)
                  : AppColors.borderColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? LucideIcons.circleCheck : LucideIcons.user,
                color:
                    selected ? AppColors.warmOrange : AppColors.textSecondary,
                size: 17,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
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

class _ProductPickerTile extends StatelessWidget {
  const _ProductPickerTile({
    required this.product,
    required this.added,
    required this.onTap,
  });

  final SaleableProduct product;
  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = product.stock > .005;
    return Material(
      color: AppColors.charcoalMedium,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: available && !added ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color:
                      (available ? AppColors.blueMuted : AppColors.errorColor)
                          .withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  product.trackSerials
                      ? LucideIcons.scanLine
                      : LucideIcons.package,
                  color: available ? AppColors.blueMuted : AppColors.errorColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_money(product.price)} • ${_quantity(product.stock)} in stock',
                      style: TextStyle(
                        color: available
                            ? AppColors.textSecondary
                            : AppColors.errorColor,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                added ? LucideIcons.circleCheck : LucideIcons.plus,
                color: added
                    ? AppColors.successColor
                    : available
                        ? AppColors.warmOrange
                        : AppColors.mutedColor,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.text, this.action});

  final String text;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.charcoalMedium,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Icon(
            LucideIcons.info,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: action, child: const Text('Create customer')),
          ],
        ],
      ),
    );
  }
}

class _SalesDialogShell extends StatelessWidget {
  const _SalesDialogShell({
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
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Container(
          width: maxWidth,
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * .92,
          ),
          decoration: BoxDecoration(
            color: AppColors.charcoalMedium,
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
            border: Border.all(color: AppColors.borderColor),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 34,
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
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, size: 20),
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
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: onSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.warmOrange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                      ),
                      icon: const Icon(LucideIcons.circleCheck, size: 17),
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

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AlertDialog(
        backgroundColor: AppColors.charcoalMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
          side: BorderSide(color: AppColors.borderColor),
        ),
        icon: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep document'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
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
                if (index > 0) const SizedBox(width: 10),
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
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool number;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType:
          number ? const TextInputType.numberWithOptions(decimal: true) : null,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _ConvertQuotationDialog extends StatefulWidget {
  const _ConvertQuotationDialog({
    required this.document,
    required this.currentUser,
  });

  final ComputerDocument document;
  final String? currentUser;

  @override
  State<_ConvertQuotationDialog> createState() =>
      _ConvertQuotationDialogState();
}

class _ConvertQuotationDialogState extends State<_ConvertQuotationDialog> {
  final List<_PaymentDraft> _payments = [];
  bool _confirmed = false;

  double get _entered => _payments.fold<double>(
        0,
        (sum, payment) => sum + (double.tryParse(payment.amount.text) ?? 0),
      );

  double get _remaining => math.max(0, widget.document.totalAmount - _entered);

  @override
  void dispose() {
    for (final payment in _payments) {
      payment.dispose();
    }
    super.dispose();
  }

  void _addPayment() {
    if (_remaining <= .005) {
      MotionSnackBarInfo(context, 'The sale total is already fully allocated.');
      return;
    }
    setState(() {
      _payments.add(
        _PaymentDraft(amount: _remaining, method: ComputerPaymentMethod.cash),
      );
    });
  }

  void _removePayment(_PaymentDraft payment) {
    setState(() => _payments.remove(payment));
    payment.dispose();
  }

  void _submit() {
    if (!_confirmed) {
      MotionSnackBarWarning(
        context,
        'Confirm the stock, serial and payment details before converting.',
      );
      return;
    }
    final inputs = _validatePaymentDrafts(
      context,
      _payments,
      maximum: widget.document.totalAmount,
      currentUser: widget.currentUser,
    );
    if (inputs == null) return;
    Navigator.pop(context, inputs);
  }

  @override
  Widget build(BuildContext context) {
    final serializedUnits = widget.document.lines
        .where((line) => line.trackSerials)
        .fold<int>(0, (sum, line) => sum + line.quantity.toInt());
    return _SalesDialogShell(
      title: 'Convert quotation to sale',
      subtitle:
          '${widget.document.documentNumber} • stock is deducted only after confirmation',
      icon: LucideIcons.arrowRight,
      actionLabel: 'Confirm & create sale',
      onSubmit: _submit,
      maxWidth: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warmOrange.withValues(alpha: .12),
                  AppColors.warmOrange.withValues(alpha: .04),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.warmOrange.withValues(alpha: .3),
              ),
            ),
            child: Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _SummaryMetric('Customer', widget.document.customerName),
                _SummaryMetric(
                    'Products', '${widget.document.lines.length} lines'),
                _SummaryMetric('Serialized units', '$serializedUnits'),
                _SummaryMetric(
                  'Sale total',
                  _money(widget.document.totalAmount),
                  strong: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoBanner(
            color: AppColors.blueMuted,
            icon: LucideIcons.info,
            text: serializedUnits > 0
                ? '$serializedUnits selected serial ${serializedUnits == 1 ? 'number will' : 'numbers will'} be marked sold and warranty dates will begin today.'
                : 'Inventory quantities will be reduced and warranty dates will begin today.',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Initial split payments',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Optional — leave empty to create an unpaid sale.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _addPayment,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add payment'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_payments.isEmpty)
            const _InlineEmpty(
              text:
                  'No initial payment. You can record one later from the sale document.',
            )
          else
            for (var index = 0; index < _payments.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _PaymentEntryCard(
                index: index,
                payment: _payments[index],
                onChanged: () => setState(() {}),
                onRemove: () => _removePayment(_payments[index]),
              ),
            ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.charcoalLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              children: [
                Expanded(child: _SummaryMetric('Entered', _money(_entered))),
                Expanded(
                  child: _SummaryMetric(
                    'Balance after sale',
                    _money(_remaining),
                    strong: _remaining > .005,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.successColor.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.successColor.withValues(alpha: .24),
              ),
            ),
            child: CheckboxListTile(
              value: _confirmed,
              onChanged: (value) => setState(() => _confirmed = value ?? false),
              activeColor: AppColors.successColor,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'I confirm the products, serial numbers and payment amounts.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'This creates a completed sale and cannot be reversed; use a manager return if needed.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.balance, required this.currentUser});

  final double balance;
  final String? currentUser;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _PaymentDraft _payment;

  @override
  void initState() {
    super.initState();
    _payment = _PaymentDraft(
      amount: widget.balance,
      method: ComputerPaymentMethod.cash,
    );
  }

  @override
  void dispose() {
    _payment.dispose();
    super.dispose();
  }

  void _submit() {
    final values = _validatePaymentDrafts(
      context,
      [_payment],
      maximum: widget.balance,
      currentUser: widget.currentUser,
    );
    if (values == null) return;
    Navigator.pop(context, values.single);
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_payment.amount.text) ?? 0;
    return _SalesDialogShell(
      title: 'Record customer payment',
      subtitle: 'Outstanding balance ${_money(widget.balance)}',
      icon: LucideIcons.walletCards,
      actionLabel: 'Record payment',
      onSubmit: _submit,
      maxWidth: 590,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PaymentEntryCard(
            index: 0,
            payment: _payment,
            onChanged: () => setState(() {}),
            showRemove: false,
          ),
          const SizedBox(height: 12),
          _InfoBanner(
            color: amount > widget.balance + .005
                ? AppColors.errorColor
                : AppColors.successColor,
            icon: amount > widget.balance + .005
                ? LucideIcons.triangleAlert
                : LucideIcons.circleCheck,
            text: amount > widget.balance + .005
                ? 'Payment is ${_money(amount - widget.balance)} above the outstanding balance.'
                : 'Remaining after payment: ${_money(math.max(0, widget.balance - amount))}',
          ),
        ],
      ),
    );
  }
}

class _PaymentDraft {
  _PaymentDraft({
    required double amount,
    required this.method,
  }) : amount = TextEditingController(text: amount.toStringAsFixed(2));

  final TextEditingController amount;
  final TextEditingController reference = TextEditingController();
  final TextEditingController notes = TextEditingController();
  ComputerPaymentMethod method;

  void dispose() {
    amount.dispose();
    reference.dispose();
    notes.dispose();
  }
}

class _PaymentEntryCard extends StatelessWidget {
  const _PaymentEntryCard({
    required this.index,
    required this.payment,
    required this.onChanged,
    this.onRemove,
    this.showRemove = true,
  });

  final int index;
  final _PaymentDraft payment;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final bool showRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payment ${index + 1}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (showRemove)
                IconButton(
                  tooltip: 'Remove payment',
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    LucideIcons.x,
                    size: 17,
                    color: AppColors.errorColor,
                  ),
                ),
            ],
          ),
          _ResponsiveFields(
            children: [
              _AppField(
                controller: payment.amount,
                label: 'Amount *',
                number: true,
                onChanged: (_) => onChanged(),
              ),
              DropdownButtonFormField<ComputerPaymentMethod>(
                initialValue: payment.method,
                dropdownColor: AppColors.charcoalMedium,
                decoration: const InputDecoration(labelText: 'Method'),
                items: ComputerPaymentMethod.values
                    .map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(method.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) payment.method = value;
                  onChanged();
                },
              ),
            ],
          ),
          _ResponsiveFields(
            children: [
              _AppField(
                controller: payment.reference,
                label: 'Reference number',
                hint: 'Card, bank or wallet reference',
              ),
              _AppField(
                controller: payment.notes,
                label: 'Payment notes',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

List<PaymentInput>? _validatePaymentDrafts(
  BuildContext context,
  List<_PaymentDraft> drafts, {
  required double maximum,
  required String? currentUser,
  String noun = 'Payment',
}) {
  final result = <PaymentInput>[];
  var sum = 0.0;
  for (final draft in drafts) {
    final amount = double.tryParse(draft.amount.text);
    if (amount == null || amount <= 0) {
      MotionSnackBarWarning(context, '$noun amounts must be positive.');
      return null;
    }
    sum += amount;
    result.add(
      PaymentInput(
        amount: amount,
        method: draft.method,
        referenceNumber: draft.reference.text.trim(),
        notes: draft.notes.text.trim(),
        receivedBy: currentUser,
      ),
    );
  }
  if (sum > maximum + .005) {
    MotionSnackBarWarning(
      context,
      '${noun}s cannot exceed ${_money(maximum)}.',
    );
    return null;
  }
  return result;
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              letterSpacing: .6,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: strong ? AppColors.warmOrange : AppColors.textPrimary,
              fontSize: strong ? 15 : 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10.8,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog({
    required this.sale,
    required this.returnedSerialIds,
    required this.currentUser,
  });

  final ComputerDocument sale;
  final Set<String> returnedSerialIds;
  final String? currentUser;

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  final Set<String> _selectedLines = {};
  final Map<String, TextEditingController> _quantities = {};
  final Map<String, Set<String>> _serials = {};
  final List<_PaymentDraft> _refunds = [];
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final line in widget.sale.lines) {
      if (!line.trackSerials) {
        _quantities[line.id] = TextEditingController(text: '1');
      } else {
        _serials[line.id] = {};
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    for (final refund in _refunds) {
      refund.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  double _quantityFor(ComputerDocumentLine line) => line.trackSerials
      ? (_serials[line.id]?.length ?? 0).toDouble()
      : (double.tryParse(_quantities[line.id]?.text ?? '') ?? 0);

  double get _returnValue {
    final factor = widget.sale.subtotal <= .005
        ? 0.0
        : widget.sale.totalAmount / widget.sale.subtotal;
    final calculated = widget.sale.lines.fold<double>(0, (sum, line) {
      if (!_selectedLines.contains(line.id)) return sum;
      return sum + _quantityFor(line) * line.unitPrice * factor;
    });
    final completesRemainingReturn = widget.sale.lines.every((line) {
      if (line.returnableQuantity <= .005) return true;
      return _selectedLines.contains(line.id) &&
          _quantityFor(line) >= line.returnableQuantity - .005;
    });
    return completesRemainingReturn
        ? _effectiveTotalBefore
        : _roundMoney(calculated);
  }

  double get _netPaidBefore => _roundMoney(math.max(
        0.0,
        widget.sale.paidAmount - widget.sale.refundedAmount,
      ));

  double get _effectiveTotalBefore => _roundMoney(
        _netPaidBefore + widget.sale.balanceDue,
      );

  double get _requiredRefund {
    final effectiveAfter = _roundMoney(
      math.max(0.0, _effectiveTotalBefore - _returnValue),
    );
    return _roundMoney(math.max(0.0, _netPaidBefore - effectiveAfter));
  }

  double get _enteredRefund => _roundMoney(
        _refunds.fold<double>(
          0,
          (sum, refund) =>
              sum + _roundMoney(double.tryParse(refund.amount.text) ?? 0),
        ),
      );

  void _toggleLine(ComputerDocumentLine line, bool value) {
    setState(() {
      if (value) {
        _selectedLines.add(line.id);
      } else {
        _selectedLines.remove(line.id);
        _serials[line.id]?.clear();
      }
    });
  }

  void _toggleSerial(
    ComputerDocumentLine line,
    AvailableSerial serial,
    bool selected,
  ) {
    final values = _serials[line.id]!;
    setState(() {
      if (!selected) {
        values.remove(serial.id);
        return;
      }
      final maxCount = line.returnableQuantity.floor();
      if (values.length >= maxCount) {
        MotionSnackBarWarning(
          context,
          'Only $maxCount serialized units remain returnable.',
        );
        return;
      }
      values.add(serial.id);
      _selectedLines.add(line.id);
    });
  }

  void _addRefund() {
    final remaining = math.max(0.0, _requiredRefund - _enteredRefund);
    if (remaining <= .005) {
      MotionSnackBarInfo(
        context,
        _requiredRefund <= .005
            ? 'No cash refund is required; this return only reduces the outstanding balance.'
            : 'The required refund is already fully allocated.',
      );
      return;
    }
    setState(() {
      _refunds.add(
        _PaymentDraft(amount: remaining, method: ComputerPaymentMethod.cash),
      );
    });
  }

  void _removeRefund(_PaymentDraft refund) {
    setState(() => _refunds.remove(refund));
    refund.dispose();
  }

  void _submit() {
    if (_selectedLines.isEmpty) {
      MotionSnackBarWarning(context, 'Select at least one product to return.');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      MotionSnackBarWarning(context, 'Add a reason for this return.');
      return;
    }
    final lines = <ReturnLineInput>[];
    for (final line in widget.sale.lines) {
      if (!_selectedLines.contains(line.id)) continue;
      final quantity = _quantityFor(line);
      if (quantity <= 0) {
        MotionSnackBarWarning(
          context,
          line.trackSerials
              ? 'Select the serial numbers being returned for ${line.productName}.'
              : 'Enter a positive return quantity for ${line.productName}.',
        );
        return;
      }
      if (quantity > line.returnableQuantity + .005) {
        MotionSnackBarWarning(
          context,
          'Only ${_quantity(line.returnableQuantity)} ${line.productName} remain returnable.',
        );
        return;
      }
      if (line.trackSerials && quantity != quantity.roundToDouble()) {
        MotionSnackBarWarning(
          context,
          'Serialized returns require whole-number quantities.',
        );
        return;
      }
      lines.add(
        ReturnLineInput(
          saleItemId: line.id,
          quantity: quantity,
          serialIds: (_serials[line.id] ?? const {}).toList(growable: false),
        ),
      );
    }
    if ((_enteredRefund - _requiredRefund).abs() > .0001) {
      MotionSnackBarWarning(
        context,
        'Refund entries must total exactly ${_money(_requiredRefund)} for this return.',
      );
      return;
    }
    final refunds = _validatePaymentDrafts(
      context,
      _refunds,
      maximum: _requiredRefund,
      currentUser: widget.currentUser,
      noun: 'Refund',
    );
    if (refunds == null) return;
    Navigator.pop(
      context,
      SaleReturnInput(
        saleId: widget.sale.id,
        lines: lines,
        reason: _reason.text.trim(),
        refunds: refunds,
        createdBy: widget.currentUser,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final returnable = widget.sale.lines
        .where((line) => line.returnableQuantity > .005)
        .toList(growable: false);
    return _SalesDialogShell(
      title: 'Manager sale return',
      subtitle:
          '${widget.sale.documentNumber} • returned stock is restored automatically',
      icon: LucideIcons.rotateCcw,
      actionLabel: 'Complete return',
      onSubmit: _submit,
      maxWidth: 850,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InfoBanner(
            color: AppColors.warningColor,
            icon: LucideIcons.shieldCheck,
            text:
                'Manager-authorized action. Verify quantities, serial numbers and the cash refund before completing the return.',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Products to return',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < returnable.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _ReturnLineCard(
              line: returnable[index],
              selected: _selectedLines.contains(returnable[index].id),
              quantity: _quantities[returnable[index].id],
              availableSerials: returnable[index]
                  .serials
                  .where(
                    (serial) => !widget.returnedSerialIds.contains(serial.id),
                  )
                  .toList(growable: false),
              selectedSerials: _serials[returnable[index].id] ?? const {},
              onSelected: (value) => _toggleLine(returnable[index], value),
              onQuantityChanged: () => setState(() {}),
              onSerialChanged: (serial, value) =>
                  _toggleSerial(returnable[index], serial, value),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _AppField(
            controller: _reason,
            label: 'Return reason *',
            hint: 'Defect, wrong item, customer request, exchange…',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer refund',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'The exact refund is calculated from payments already received and the balance after this return.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _addRefund,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add refund'),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (_refunds.isEmpty)
            _InlineEmpty(
              text: _requiredRefund <= .005
                  ? 'No cash refund is required. The returned value will reduce the outstanding customer balance.'
                  : 'Add refund entries totaling exactly ${_money(_requiredRefund)} before completing this return.',
            )
          else
            for (var index = 0; index < _refunds.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _PaymentEntryCard(
                index: index,
                payment: _refunds[index],
                onChanged: () => setState(() {}),
                onRemove: () => _removeRefund(_refunds[index]),
              ),
            ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.charcoalLight,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _SummaryMetric('Return value', _money(_returnValue)),
                _SummaryMetric(
                  'Required refund',
                  _money(_requiredRefund),
                ),
                _SummaryMetric(
                  'Refund entered',
                  _money(_enteredRefund),
                  strong: _enteredRefund > .005,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnLineCard extends StatelessWidget {
  const _ReturnLineCard({
    required this.line,
    required this.selected,
    required this.quantity,
    required this.availableSerials,
    required this.selectedSerials,
    required this.onSelected,
    required this.onQuantityChanged,
    required this.onSerialChanged,
  });

  final ComputerDocumentLine line;
  final bool selected;
  final TextEditingController? quantity;
  final List<AvailableSerial> availableSerials;
  final Set<String> selectedSerials;
  final ValueChanged<bool> onSelected;
  final VoidCallback onQuantityChanged;
  final void Function(AvailableSerial serial, bool selected) onSerialChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.errorColor.withValues(alpha: .06)
            : AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? AppColors.errorColor.withValues(alpha: .32)
              : AppColors.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                activeColor: AppColors.errorColor,
                onChanged: (value) => onSelected(value ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.productName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_quantity(line.returnableQuantity)} returnable • ${_money(line.unitPrice)} each',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (!line.trackSerials && selected)
                SizedBox(
                  width: 112,
                  child: _AppField(
                    controller: quantity!,
                    label: 'Return qty',
                    number: true,
                    onChanged: (_) => onQuantityChanged(),
                  ),
                ),
            ],
          ),
          if (line.trackSerials && selected) ...[
            const SizedBox(height: 9),
            Text(
              'Select returned serial numbers',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            if (availableSerials.isEmpty)
              const _InfoBanner(
                color: AppColors.errorColor,
                icon: LucideIcons.triangleAlert,
                text: 'No sold serial numbers remain available for return.',
              )
            else
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final serial in availableSerials)
                    FilterChip(
                      selected: selectedSerials.contains(serial.id),
                      onSelected: (value) => onSerialChanged(serial, value),
                      checkmarkColor: Colors.white,
                      selectedColor: AppColors.errorColor,
                      backgroundColor: AppColors.charcoalMedium,
                      side: BorderSide(color: AppColors.borderColor),
                      label: Text(serial.serialNumber),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3.5 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 9.5 : 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
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

class _InfoData {
  const _InfoData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: AppColors.charcoalMedium,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      border: Border.all(color: AppColors.borderColor),
      boxShadow: AppColors.isDarkMode
          ? null
          : const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
    );

Color _documentStatusColor(ComputerDocumentStatus status) => switch (status) {
      ComputerDocumentStatus.draft => AppColors.blueMuted,
      ComputerDocumentStatus.converted => AppColors.successColor,
      ComputerDocumentStatus.cancelled => AppColors.errorColor,
      ComputerDocumentStatus.completed => AppColors.successColor,
      ComputerDocumentStatus.partiallyReturned => AppColors.warningColor,
      ComputerDocumentStatus.returned => AppColors.errorColor,
    };

Color _paymentStatusColor(ComputerPaymentStatus status) => switch (status) {
      ComputerPaymentStatus.unpaid => AppColors.errorColor,
      ComputerPaymentStatus.partial => AppColors.warningColor,
      ComputerPaymentStatus.paid => AppColors.successColor,
      ComputerPaymentStatus.partiallyRefunded => AppColors.warningColor,
      ComputerPaymentStatus.refunded => AppColors.errorColor,
    };

final NumberFormat _moneyFormat =
    NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2);
final DateFormat _shortDateFormat = DateFormat('dd MMM yyyy');
final DateFormat _longDateFormat = DateFormat('dd MMMM yyyy');
final DateFormat _longDateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

String _money(double value) => _moneyFormat.format(value);
double _roundMoney(double value) => (value * 100).round() / 100;
String _shortDate(DateTime value) => _shortDateFormat.format(value);
String _longDate(DateTime value) => _longDateFormat.format(value);
String _longDateTime(DateTime value) => _longDateTimeFormat.format(value);
String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;
