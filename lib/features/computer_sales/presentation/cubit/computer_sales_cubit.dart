import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/security/permission_guard.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/computer_sales_models.dart';
import '../../data/computer_sales_repository.dart';

class ComputerSalesState {
  const ComputerSalesState({
    this.loading = false,
    this.saving = false,
    this.documents = const [],
    this.customers = const [],
    this.products = const [],
    this.stats = const ComputerSalesStats(),
    this.selectedDocument,
    this.search = '',
    this.customerSearch = '',
    this.productSearch = '',
    this.typeFilter,
    this.statusFilter,
    this.paymentFilter,
    this.error,
    this.notice,
  });

  final bool loading;
  final bool saving;
  final List<ComputerDocument> documents;
  final List<ComputerCustomer> customers;
  final List<SaleableProduct> products;
  final ComputerSalesStats stats;
  final ComputerDocument? selectedDocument;
  final String search;
  final String customerSearch;
  final String productSearch;
  final ComputerDocumentType? typeFilter;
  final ComputerDocumentStatus? statusFilter;
  final ComputerPaymentStatus? paymentFilter;
  final String? error;
  final String? notice;

  ComputerSalesState copyWith({
    bool? loading,
    bool? saving,
    List<ComputerDocument>? documents,
    List<ComputerCustomer>? customers,
    List<SaleableProduct>? products,
    ComputerSalesStats? stats,
    ComputerDocument? selectedDocument,
    bool clearSelectedDocument = false,
    String? search,
    String? customerSearch,
    String? productSearch,
    ComputerDocumentType? typeFilter,
    bool clearTypeFilter = false,
    ComputerDocumentStatus? statusFilter,
    bool clearStatusFilter = false,
    ComputerPaymentStatus? paymentFilter,
    bool clearPaymentFilter = false,
    String? error,
    String? notice,
    bool clearMessages = false,
  }) =>
      ComputerSalesState(
        loading: loading ?? this.loading,
        saving: saving ?? this.saving,
        documents: documents ?? this.documents,
        customers: customers ?? this.customers,
        products: products ?? this.products,
        stats: stats ?? this.stats,
        selectedDocument: clearSelectedDocument
            ? null
            : selectedDocument ?? this.selectedDocument,
        search: search ?? this.search,
        customerSearch: customerSearch ?? this.customerSearch,
        productSearch: productSearch ?? this.productSearch,
        typeFilter: clearTypeFilter ? null : typeFilter ?? this.typeFilter,
        statusFilter:
            clearStatusFilter ? null : statusFilter ?? this.statusFilter,
        paymentFilter:
            clearPaymentFilter ? null : paymentFilter ?? this.paymentFilter,
        error: clearMessages ? null : error ?? this.error,
        notice: clearMessages ? null : notice ?? this.notice,
      );
}

class ComputerSalesCubit extends Cubit<ComputerSalesState> {
  ComputerSalesCubit(
    this._repository, {
    required User Function() currentUser,
  })  : _currentUser = currentUser,
        super(const ComputerSalesState()) {
    _subscription = _repository.changes.listen((_) => _scheduleRefresh());
  }

  final ComputerSalesRepository _repository;
  final User Function() _currentUser;
  StreamSubscription<void>? _subscription;
  Timer? _refreshTimer;
  bool _refreshRunning = false;
  bool _refreshRequested = false;
  int _documentLoadRevision = 0;
  int _customerLoadRevision = 0;
  int _productLoadRevision = 0;
  int _selectionRevision = 0;
  int _mutationRevision = 0;

  Future<void> initialize() async {
    await Future.wait([load(), loadCustomers(), loadProducts()]);
  }

  Future<void> load({
    String? search,
    ComputerDocumentType? type,
    bool clearType = false,
    ComputerDocumentStatus? status,
    bool clearStatus = false,
    ComputerPaymentStatus? paymentStatus,
    bool clearPayment = false,
  }) async {
    final revision = ++_documentLoadRevision;
    final nextSearch = search ?? state.search;
    final nextType = clearType ? null : type ?? state.typeFilter;
    final nextStatus = clearStatus ? null : status ?? state.statusFilter;
    final nextPayment =
        clearPayment ? null : paymentStatus ?? state.paymentFilter;
    _emit(state.copyWith(
      loading: true,
      search: nextSearch,
      typeFilter: nextType,
      clearTypeFilter: clearType,
      statusFilter: nextStatus,
      clearStatusFilter: clearStatus,
      paymentFilter: nextPayment,
      clearPaymentFilter: clearPayment,
      clearMessages: true,
    ));
    try {
      final values = await Future.wait<Object>([
        _repository.listDocuments(
          search: nextSearch,
          type: nextType,
          status: nextStatus,
          paymentStatus: nextPayment,
        ),
        _repository.getStats(),
      ]);
      if (isClosed || revision != _documentLoadRevision) return;
      _emit(state.copyWith(
        loading: false,
        documents: values[0] as List<ComputerDocument>,
        stats: values[1] as ComputerSalesStats,
      ));
    } catch (error) {
      if (isClosed || revision != _documentLoadRevision) return;
      _emit(state.copyWith(loading: false, error: _friendlyError(error)));
    }
  }

  Future<void> loadCustomers({String? search}) async {
    final revision = ++_customerLoadRevision;
    final nextSearch = search ?? state.customerSearch;
    try {
      final customers = await _repository.searchCustomers(search: nextSearch);
      if (isClosed || revision != _customerLoadRevision) return;
      _emit(state.copyWith(
        customers: customers,
        customerSearch: nextSearch,
        clearMessages: true,
      ));
    } catch (error) {
      if (isClosed || revision != _customerLoadRevision) return;
      _emit(state.copyWith(error: _friendlyError(error)));
    }
  }

  Future<void> loadProducts({String? search}) async {
    final revision = ++_productLoadRevision;
    final nextSearch = search ?? state.productSearch;
    try {
      final products =
          await _repository.getSaleableProducts(search: nextSearch);
      if (isClosed || revision != _productLoadRevision) return;
      _emit(state.copyWith(
        products: products,
        productSearch: nextSearch,
        clearMessages: true,
      ));
    } catch (error) {
      if (isClosed || revision != _productLoadRevision) return;
      _emit(state.copyWith(error: _friendlyError(error)));
    }
  }

  Future<List<AvailableSerial>> getAvailableSerials(
    String productId, {
    String? forQuotationId,
  }) async {
    try {
      return await _repository.getAvailableSerials(
        productId,
        forQuotationId: forQuotationId,
      );
    } catch (error) {
      _emit(state.copyWith(error: _friendlyError(error)));
      return const [];
    }
  }

  Future<ComputerDocument?> selectDocument(String id) async {
    final revision = ++_selectionRevision;
    try {
      final document = await _repository.getDocument(id);
      if (isClosed || revision != _selectionRevision) return document;
      _emit(state.copyWith(selectedDocument: document, clearMessages: true));
      return document;
    } catch (error) {
      if (isClosed || revision != _selectionRevision) return null;
      _emit(state.copyWith(error: _friendlyError(error)));
      return null;
    }
  }

  void clearSelection() {
    _selectionRevision++;
    _emit(state.copyWith(clearSelectedDocument: true));
  }

  void clearMessages() => _emit(state.copyWith(clearMessages: true));

  Future<ComputerCustomer?> createCustomer(
    NewComputerCustomerInput input,
  ) async {
    final revision = _beginMutation();
    _emit(state.copyWith(
      loading: false,
      saving: true,
      clearMessages: true,
    ));
    try {
      _requireActor(AppPermission.processComputerSales);
      final customer = await _repository.createCustomer(input);
      if (isClosed || revision != _mutationRevision) return customer;
      _emit(state.copyWith(
        saving: false,
        customers: [customer, ...state.customers],
        notice: 'Customer created successfully.',
      ));
      return customer;
    } catch (error) {
      if (isClosed || revision != _mutationRevision) return null;
      _emit(state.copyWith(saving: false, error: _friendlyError(error)));
      return null;
    }
  }

  Future<ComputerDocument?> createQuotation(
    DraftQuotationInput input,
  ) async {
    return _saveDocument(
      operation: () {
        final actor = _requireActor(AppPermission.processComputerSales);
        return _repository.createDraftQuotation(
          _quotationAsActor(input, actor.username),
        );
      },
      successMessage: 'Quotation created successfully.',
    );
  }

  Future<ComputerDocument?> updateQuotation(
    String quotationId,
    DraftQuotationInput input,
  ) async {
    return _saveDocument(
      operation: () {
        final actor = _requireActor(AppPermission.processComputerSales);
        return _repository.updateDraftQuotation(
          quotationId,
          _quotationAsActor(input, actor.username),
        );
      },
      successMessage: 'Quotation updated successfully.',
    );
  }

  Future<bool> cancelQuotation(String quotationId) async {
    final revision = _beginMutation();
    _emit(state.copyWith(
      loading: false,
      saving: true,
      clearMessages: true,
    ));
    try {
      _requireActor(AppPermission.processComputerSales);
      await _repository.cancelQuotation(quotationId);
      if (isClosed || revision != _mutationRevision) return true;
      _selectionRevision++;
      _emit(state.copyWith(
        saving: false,
        clearSelectedDocument: true,
        notice: 'Quotation cancelled.',
      ));
      return true;
    } catch (error) {
      if (isClosed || revision != _mutationRevision) return false;
      _emit(state.copyWith(saving: false, error: _friendlyError(error)));
      return false;
    }
  }

  Future<ComputerDocument?> convertQuotation(
    String quotationId, {
    List<PaymentInput> payments = const [],
  }) async {
    return _saveDocument(
      operation: () {
        final actor = _requireActor(AppPermission.processComputerSales);
        return _repository.convertQuotation(
          quotationId,
          payments: payments
              .map((payment) => _paymentAsActor(payment, actor.username))
              .toList(growable: false),
          createdBy: actor.username,
        );
      },
      successMessage: 'Quotation converted to a sale.',
    );
  }

  Future<ComputerDocument?> addPayment(
    String saleId,
    PaymentInput payment,
  ) async {
    return _saveDocument(
      operation: () {
        final actor = _requireActor(AppPermission.processPayments);
        return _repository.addPayment(
          saleId,
          _paymentAsActor(payment, actor.username),
        );
      },
      successMessage: 'Payment recorded successfully.',
    );
  }

  Future<ComputerReturn?> createReturn(SaleReturnInput input) async {
    final revision = _beginMutation();
    _emit(state.copyWith(
      loading: false,
      saving: true,
      clearMessages: true,
    ));
    try {
      final actor = _requireActor(AppPermission.processRefunds);
      final authorizedInput = SaleReturnInput(
        saleId: input.saleId,
        lines: input.lines,
        reason: input.reason,
        refunds: input.refunds
            .map((refund) => _paymentAsActor(refund, actor.username))
            .toList(growable: false),
        createdBy: actor.username,
      );
      final result = await _repository.createReturn(authorizedInput);
      final refreshedSale = await _repository.getDocument(input.saleId);
      if (isClosed || revision != _mutationRevision) return result;
      _selectionRevision++;
      _emit(state.copyWith(
        saving: false,
        selectedDocument: refreshedSale,
        notice: 'Return and stock restoration completed.',
      ));
      return result;
    } catch (error) {
      if (isClosed || revision != _mutationRevision) return null;
      _emit(state.copyWith(saving: false, error: _friendlyError(error)));
      return null;
    }
  }

  Future<List<ComputerReturn>> loadReturns({String? saleId}) async {
    try {
      return await _repository.listReturns(saleId: saleId);
    } catch (error) {
      _emit(state.copyWith(error: _friendlyError(error)));
      return const [];
    }
  }

  Future<ComputerDocument?> _saveDocument({
    required Future<ComputerDocument> Function() operation,
    required String successMessage,
  }) async {
    final revision = _beginMutation();
    _emit(state.copyWith(
      loading: false,
      saving: true,
      clearMessages: true,
    ));
    try {
      final document = await operation();
      if (isClosed || revision != _mutationRevision) return document;
      _selectionRevision++;
      _emit(state.copyWith(
        saving: false,
        selectedDocument: document,
        notice: successMessage,
      ));
      return document;
    } catch (error) {
      if (isClosed || revision != _mutationRevision) return null;
      _emit(state.copyWith(saving: false, error: _friendlyError(error)));
      return null;
    }
  }

  void _scheduleRefresh() {
    if (isClosed) return;
    _refreshRequested = true;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 60), () {
      unawaited(_drainRefreshes());
    });
  }

  int _beginMutation() {
    _documentLoadRevision++;
    _customerLoadRevision++;
    _productLoadRevision++;
    _selectionRevision++;
    return ++_mutationRevision;
  }

  Future<void> _drainRefreshes() async {
    if (_refreshRunning || isClosed) return;
    _refreshRunning = true;
    try {
      while (_refreshRequested && !isClosed) {
        _refreshRequested = false;
        final selectedId = state.selectedDocument?.id;
        await Future.wait([load(), loadProducts(), loadCustomers()]);
        if (isClosed) return;
        if (selectedId != null && state.selectedDocument?.id == selectedId) {
          await selectDocument(selectedId);
        }
      }
    } finally {
      _refreshRunning = false;
      if (_refreshRequested && !isClosed) _scheduleRefresh();
    }
  }

  void _emit(ComputerSalesState nextState) {
    if (!isClosed) emit(nextState);
  }

  String _friendlyError(Object error) {
    if (error is ComputerSalesException) return error.message;
    if (error is PermissionDeniedException) return error.message;
    final message = error.toString().toLowerCase();
    if (message.contains('unique constraint') ||
        message.contains('sqlite_constraint')) {
      if (message.contains('document_number') ||
          message.contains('return_number')) {
        return 'A document number conflict occurred. Please try again.';
      }
      return 'This record already exists.';
    }
    return 'The change could not be saved. Please try again.';
  }

  User _requireActor(AppPermission permission) {
    final actor = _currentUser();
    PermissionGuard.require(
      actor,
      permission,
      message: permission == AppPermission.processRefunds
          ? 'Computer-sale returns and refunds are available to managers only.'
          : 'Your role is not authorized to perform this computer-sales action.',
    );
    return actor;
  }

  static DraftQuotationInput _quotationAsActor(
    DraftQuotationInput input,
    String actorId,
  ) =>
      DraftQuotationInput(
        customerId: input.customerId,
        lines: input.lines,
        expiryDate: input.expiryDate,
        discountAmount: input.discountAmount,
        taxRate: input.taxRate,
        notes: input.notes,
        createdBy: actorId,
      );

  static PaymentInput _paymentAsActor(PaymentInput input, String actorId) =>
      PaymentInput(
        amount: input.amount,
        method: input.method,
        referenceNumber: input.referenceNumber,
        notes: input.notes,
        receivedBy: actorId,
      );

  @override
  Future<void> close() async {
    _refreshTimer?.cancel();
    _refreshRequested = false;
    _documentLoadRevision++;
    _customerLoadRevision++;
    _productLoadRevision++;
    _selectionRevision++;
    _mutationRevision++;
    await _subscription?.cancel();
    return super.close();
  }
}
