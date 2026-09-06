// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/dynamic_form_field/dynamic_form_field.dart';
import 'dynamic_form_field_presenter.dart';

class DynamicFormFieldController extends Controller {
  DynamicFormFieldController(this._presenter);

  final DynamicFormFieldPresenter _presenter;

  Future<void> getDynamicFormField(
    String id, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.getDynamicFormField(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateDynamicFormField(
    String id,
    DynamicFormFieldPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateDynamicFormField(
      id,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleDynamicFormField(
    String id,
    Field<DynamicFormField, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleDynamicFormField(
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
