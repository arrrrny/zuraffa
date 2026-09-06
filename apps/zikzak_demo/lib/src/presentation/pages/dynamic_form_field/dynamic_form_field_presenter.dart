// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/dynamic_form_field/dynamic_form_field.dart';
import '../../../domain/usecases/dynamic_form_field/get_dynamic_form_field_usecase.dart';
import '../../../domain/usecases/dynamic_form_field/toggle_dynamic_form_field_usecase.dart';
import '../../../domain/usecases/dynamic_form_field/update_dynamic_form_field_usecase.dart';

class DynamicFormFieldPresenter extends Presenter {
  DynamicFormFieldPresenter() {
    _getDynamicFormField = registerUseCase(getIt<GetDynamicFormFieldUseCase>());
    _updateDynamicFormField = registerUseCase(
      getIt<UpdateDynamicFormFieldUseCase>(),
    );
    _toggleDynamicFormField = registerUseCase(
      getIt<ToggleDynamicFormFieldUseCase>(),
    );
  }

  late final GetDynamicFormFieldUseCase _getDynamicFormField;

  late final UpdateDynamicFormFieldUseCase _updateDynamicFormField;

  late final ToggleDynamicFormFieldUseCase _toggleDynamicFormField;

  Future<Result<DynamicFormField, AppFailure>> getDynamicFormField(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getDynamicFormField.call(
      QueryParams<DynamicFormField>(filter: Eq(DynamicFormFieldFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<DynamicFormField, AppFailure>> updateDynamicFormField(
    String id,
    DynamicFormFieldPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateDynamicFormField.call(
      UpdateParams<String, DynamicFormFieldPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<DynamicFormField, AppFailure>> toggleDynamicFormField(
    String id,
    Field<DynamicFormField, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleDynamicFormField.call(
      ToggleParams<String, Field<DynamicFormField, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
