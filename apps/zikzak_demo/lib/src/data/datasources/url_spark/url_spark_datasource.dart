// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/url_spark/url_spark.dart';

abstract class UrlSparkDataSource with Loggable, FailureHandler {
  Future<UrlSpark> get(QueryParams<UrlSpark> params);
  Future<UrlSpark> update(UpdateParams<String, UrlSparkPatch> params);
  Future<UrlSpark> toggle(
    ToggleParams<String, Field<UrlSpark, dynamic>> params,
  );
}

// END GENERATED
