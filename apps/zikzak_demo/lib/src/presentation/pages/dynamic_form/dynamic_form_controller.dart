// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/dynamic_form/dynamic_form.dart';
import 'dynamic_form_presenter.dart';

class DynamicFormController extends Controller {
  DynamicFormController(this._presenter);

  final DynamicFormPresenter _presenter;

  Future<void> getDynamicForm(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getDynamicForm(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateDynamicForm(
    String id,
    DynamicFormPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateDynamicForm(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleDynamicForm(
    String id,
    Field<DynamicForm, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleDynamicForm(
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
