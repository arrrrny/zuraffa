// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/customer/customer.dart';
import '../../../domain/usecases/customer/get_customer_usecase.dart';
import '../../../domain/usecases/customer/toggle_customer_usecase.dart';
import '../../../domain/usecases/customer/update_customer_usecase.dart';

class CustomerPresenter extends Presenter {
  CustomerPresenter() {
    _getCustomer = registerUseCase(getIt<GetCustomerUseCase>());
    _updateCustomer = registerUseCase(getIt<UpdateCustomerUseCase>());
    _toggleCustomer = registerUseCase(getIt<ToggleCustomerUseCase>());
  }

  late final GetCustomerUseCase _getCustomer;

  late final UpdateCustomerUseCase _updateCustomer;

  late final ToggleCustomerUseCase _toggleCustomer;

  Future<Result<Customer, AppFailure>> getCustomer(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getCustomer.call(
      QueryParams<Customer>(filter: Eq(CustomerFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Customer, AppFailure>> updateCustomer(
    String id,
    CustomerPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateCustomer.call(
      UpdateParams<String, CustomerPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Customer, AppFailure>> toggleCustomer(
    String id,
    Field<Customer, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleCustomer.call(
      ToggleParams<String, Field<Customer, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
