// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/customer_address/customer_address.dart';
import '../../../domain/usecases/customer_address/get_customer_address_usecase.dart';
import '../../../domain/usecases/customer_address/toggle_customer_address_usecase.dart';
import '../../../domain/usecases/customer_address/update_customer_address_usecase.dart';

class CustomerAddressPresenter extends Presenter {
  CustomerAddressPresenter() {
    _getCustomerAddress = registerUseCase(getIt<GetCustomerAddressUseCase>());
    _updateCustomerAddress = registerUseCase(
      getIt<UpdateCustomerAddressUseCase>(),
    );
    _toggleCustomerAddress = registerUseCase(
      getIt<ToggleCustomerAddressUseCase>(),
    );
  }

  late final GetCustomerAddressUseCase _getCustomerAddress;

  late final UpdateCustomerAddressUseCase _updateCustomerAddress;

  late final ToggleCustomerAddressUseCase _toggleCustomerAddress;

  Future<Result<CustomerAddress, AppFailure>> getCustomerAddress(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getCustomerAddress.call(
      QueryParams<CustomerAddress>(filter: Eq(CustomerAddressFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<CustomerAddress, AppFailure>> updateCustomerAddress(
    String id,
    CustomerAddressPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateCustomerAddress.call(
      UpdateParams<String, CustomerAddressPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<CustomerAddress, AppFailure>> toggleCustomerAddress(
    String id,
    Field<CustomerAddress, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleCustomerAddress.call(
      ToggleParams<String, Field<CustomerAddress, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
