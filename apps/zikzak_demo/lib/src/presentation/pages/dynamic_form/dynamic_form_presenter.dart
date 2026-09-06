// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/dynamic_form/dynamic_form.dart';
import '../../../domain/usecases/dynamic_form/get_dynamic_form_usecase.dart';
import '../../../domain/usecases/dynamic_form/toggle_dynamic_form_usecase.dart';
import '../../../domain/usecases/dynamic_form/update_dynamic_form_usecase.dart';

class DynamicFormPresenter extends Presenter {
  DynamicFormPresenter() {
    _getDynamicForm = registerUseCase(getIt<GetDynamicFormUseCase>());
    _updateDynamicForm = registerUseCase(getIt<UpdateDynamicFormUseCase>());
    _toggleDynamicForm = registerUseCase(getIt<ToggleDynamicFormUseCase>());
  }

  late final GetDynamicFormUseCase _getDynamicForm;

  late final UpdateDynamicFormUseCase _updateDynamicForm;

  late final ToggleDynamicFormUseCase _toggleDynamicForm;

  Future<Result<DynamicForm, AppFailure>> getDynamicForm(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getDynamicForm.call(
      QueryParams<DynamicForm>(filter: Eq(DynamicFormFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<DynamicForm, AppFailure>> updateDynamicForm(
    String id,
    DynamicFormPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateDynamicForm.call(
      UpdateParams<String, DynamicFormPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<DynamicForm, AppFailure>> toggleDynamicForm(
    String id,
    Field<DynamicForm, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleDynamicForm.call(
      ToggleParams<String, Field<DynamicForm, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
