// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/url_spark/url_spark.dart';
import '../../../domain/usecases/url_spark/get_url_spark_usecase.dart';
import '../../../domain/usecases/url_spark/toggle_url_spark_usecase.dart';
import '../../../domain/usecases/url_spark/update_url_spark_usecase.dart';

class UrlSparkPresenter extends Presenter {
  UrlSparkPresenter() {
    _getUrlSpark = registerUseCase(getIt<GetUrlSparkUseCase>());
    _updateUrlSpark = registerUseCase(getIt<UpdateUrlSparkUseCase>());
    _toggleUrlSpark = registerUseCase(getIt<ToggleUrlSparkUseCase>());
  }

  late final GetUrlSparkUseCase _getUrlSpark;

  late final UpdateUrlSparkUseCase _updateUrlSpark;

  late final ToggleUrlSparkUseCase _toggleUrlSpark;

  Future<Result<UrlSpark, AppFailure>> getUrlSpark(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getUrlSpark.call(
      QueryParams<UrlSpark>(filter: Eq(UrlSparkFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<UrlSpark, AppFailure>> updateUrlSpark(
    String id,
    UrlSparkPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateUrlSpark.call(
      UpdateParams<String, UrlSparkPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<UrlSpark, AppFailure>> toggleUrlSpark(
    String id,
    Field<UrlSpark, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleUrlSpark.call(
      ToggleParams<String, Field<UrlSpark, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
