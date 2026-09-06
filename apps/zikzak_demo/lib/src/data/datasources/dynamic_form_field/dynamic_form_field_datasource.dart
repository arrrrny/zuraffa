// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/dynamic_form_field/dynamic_form_field.dart';

abstract class DynamicFormFieldDataSource with Loggable, FailureHandler {
  Future<DynamicFormField> get(QueryParams<DynamicFormField> params);
  Future<DynamicFormField> update(
    UpdateParams<String, DynamicFormFieldPatch> params,
  );
  Future<DynamicFormField> toggle(
    ToggleParams<String, Field<DynamicFormField, dynamic>> params,
  );
}

// END GENERATED
