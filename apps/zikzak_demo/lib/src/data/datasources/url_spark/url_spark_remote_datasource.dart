// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/url_spark/url_spark.dart';
import 'url_spark_datasource.dart';

class UrlSparkRemoteDataSource
    with Loggable, FailureHandler
    implements UrlSparkDataSource {
  @override
  Future<UrlSpark> get(QueryParams<UrlSpark> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<UrlSpark> update(UpdateParams<String, UrlSparkPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<UrlSpark> toggle(
    ToggleParams<String, Field<UrlSpark, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
