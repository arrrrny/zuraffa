// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/customer_address/customer_address.dart';
import 'customer_address_presenter.dart';

class CustomerAddressController extends Controller {
  CustomerAddressController(this._presenter);

  final CustomerAddressPresenter _presenter;

  Future<void> getCustomerAddress(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getCustomerAddress(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateCustomerAddress(
    String id,
    CustomerAddressPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateCustomerAddress(
      id,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleCustomerAddress(
    String id,
    Field<CustomerAddress, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleCustomerAddress(
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
