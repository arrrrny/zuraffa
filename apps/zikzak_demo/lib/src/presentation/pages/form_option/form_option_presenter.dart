// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/form_option/form_option.dart';
import '../../../domain/usecases/form_option/get_form_option_usecase.dart';
import '../../../domain/usecases/form_option/toggle_form_option_usecase.dart';
import '../../../domain/usecases/form_option/update_form_option_usecase.dart';

class FormOptionPresenter extends Presenter {
  FormOptionPresenter() {
    _getFormOption = registerUseCase(getIt<GetFormOptionUseCase>());
    _updateFormOption = registerUseCase(getIt<UpdateFormOptionUseCase>());
    _toggleFormOption = registerUseCase(getIt<ToggleFormOptionUseCase>());
  }

  late final GetFormOptionUseCase _getFormOption;

  late final UpdateFormOptionUseCase _updateFormOption;

  late final ToggleFormOptionUseCase _toggleFormOption;

  Future<Result<FormOption, AppFailure>> getFormOption(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getFormOption.call(
      QueryParams<FormOption>(filter: Eq(FormOptionFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<FormOption, AppFailure>> updateFormOption(
    String id,
    FormOptionPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateFormOption.call(
      UpdateParams<String, FormOptionPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<FormOption, AppFailure>> toggleFormOption(
    String id,
    Field<FormOption, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleFormOption.call(
      ToggleParams<String, Field<FormOption, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
