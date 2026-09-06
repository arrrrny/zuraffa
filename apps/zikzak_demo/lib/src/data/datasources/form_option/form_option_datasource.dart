// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/form_option/form_option.dart';

abstract class FormOptionDataSource with Loggable, FailureHandler {
  Future<FormOption> get(QueryParams<FormOption> params);
  Future<FormOption> update(UpdateParams<String, FormOptionPatch> params);
  Future<FormOption> toggle(
    ToggleParams<String, Field<FormOption, dynamic>> params,
  );
}

// END GENERATED
