// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/dynamic_form/dynamic_form.dart';

abstract class DynamicFormDataSource with Loggable, FailureHandler {
  Future<DynamicForm> get(QueryParams<DynamicForm> params);
  Future<DynamicForm> update(UpdateParams<String, DynamicFormPatch> params);
  Future<DynamicForm> toggle(
    ToggleParams<String, Field<DynamicForm, dynamic>> params,
  );
}

// END GENERATED
