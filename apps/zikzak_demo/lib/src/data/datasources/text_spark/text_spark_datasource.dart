// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/text_spark/text_spark.dart';

abstract class TextSparkDataSource with Loggable, FailureHandler {
  Future<TextSpark> get(QueryParams<TextSpark> params);
  Future<TextSpark> update(UpdateParams<String, TextSparkPatch> params);
  Future<TextSpark> toggle(
    ToggleParams<String, Field<TextSpark, dynamic>> params,
  );
}

// END GENERATED
