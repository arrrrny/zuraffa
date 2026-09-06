// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/text_spark/text_spark.dart';
import '../../../domain/usecases/text_spark/get_text_spark_usecase.dart';
import '../../../domain/usecases/text_spark/toggle_text_spark_usecase.dart';
import '../../../domain/usecases/text_spark/update_text_spark_usecase.dart';

class TextSparkPresenter extends Presenter {
  TextSparkPresenter() {
    _getTextSpark = registerUseCase(getIt<GetTextSparkUseCase>());
    _updateTextSpark = registerUseCase(getIt<UpdateTextSparkUseCase>());
    _toggleTextSpark = registerUseCase(getIt<ToggleTextSparkUseCase>());
  }

  late final GetTextSparkUseCase _getTextSpark;

  late final UpdateTextSparkUseCase _updateTextSpark;

  late final ToggleTextSparkUseCase _toggleTextSpark;

  Future<Result<TextSpark, AppFailure>> getTextSpark(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getTextSpark.call(
      QueryParams<TextSpark>(filter: Eq(TextSparkFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<TextSpark, AppFailure>> updateTextSpark(
    String id,
    TextSparkPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateTextSpark.call(
      UpdateParams<String, TextSparkPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<TextSpark, AppFailure>> toggleTextSpark(
    String id,
    Field<TextSpark, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleTextSpark.call(
      ToggleParams<String, Field<TextSpark, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
