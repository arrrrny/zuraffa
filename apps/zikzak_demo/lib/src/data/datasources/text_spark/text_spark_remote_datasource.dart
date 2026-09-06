// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/text_spark/text_spark.dart';
import 'text_spark_datasource.dart';

class TextSparkRemoteDataSource
    with Loggable, FailureHandler
    implements TextSparkDataSource {
  @override
  Future<TextSpark> get(QueryParams<TextSpark> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<TextSpark> update(UpdateParams<String, TextSparkPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<TextSpark> toggle(
    ToggleParams<String, Field<TextSpark, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
