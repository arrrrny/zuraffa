// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/locale/locale.dart';
import 'locale_presenter.dart';

class LocaleController extends Controller {
  LocaleController(this._presenter);

  final LocalePresenter _presenter;

  Future<void> getLocale(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getLocale(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateLocale(
    String id,
    LocalePatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateLocale(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleLocale(
    String id,
    Field<Locale, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleLocale(
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
