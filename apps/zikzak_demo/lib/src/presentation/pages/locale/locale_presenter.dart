// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/locale/locale.dart';
import '../../../domain/usecases/locale/get_locale_usecase.dart';
import '../../../domain/usecases/locale/toggle_locale_usecase.dart';
import '../../../domain/usecases/locale/update_locale_usecase.dart';

class LocalePresenter extends Presenter {
  LocalePresenter() {
    _getLocale = registerUseCase(getIt<GetLocaleUseCase>());
    _updateLocale = registerUseCase(getIt<UpdateLocaleUseCase>());
    _toggleLocale = registerUseCase(getIt<ToggleLocaleUseCase>());
  }

  late final GetLocaleUseCase _getLocale;

  late final UpdateLocaleUseCase _updateLocale;

  late final ToggleLocaleUseCase _toggleLocale;

  Future<Result<Locale, AppFailure>> getLocale(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getLocale.call(
      QueryParams<Locale>(filter: Eq(LocaleFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Locale, AppFailure>> updateLocale(
    String id,
    LocalePatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateLocale.call(
      UpdateParams<String, LocalePatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Locale, AppFailure>> toggleLocale(
    String id,
    Field<Locale, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleLocale.call(
      ToggleParams<String, Field<Locale, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
