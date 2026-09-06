// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/customer/customer.dart';
import 'customer_presenter.dart';

class CustomerController extends Controller {
  CustomerController(this._presenter);

  final CustomerPresenter _presenter;

  Future<void> getCustomer(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getCustomer(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateCustomer(
    String id,
    CustomerPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateCustomer(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleCustomer(
    String id,
    Field<Customer, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleCustomer(
      id,
      field,
      toggleValue,
      cancelToken,
    );
    result.fold((toggled) {}, (failure) {});
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}

// END GENERATED
