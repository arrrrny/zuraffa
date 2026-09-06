// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/form_option/form_option.dart';
import 'form_option_presenter.dart';

class FormOptionController extends Controller {
  FormOptionController(this._presenter);

  final FormOptionPresenter _presenter;

  Future<void> getFormOption(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getFormOption(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateFormOption(
    String id,
    FormOptionPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateFormOption(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleFormOption(
    String id,
    Field<FormOption, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleFormOption(
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
