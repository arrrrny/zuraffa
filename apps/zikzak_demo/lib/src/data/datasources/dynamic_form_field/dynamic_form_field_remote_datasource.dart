// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/dynamic_form_field/dynamic_form_field.dart';
import 'dynamic_form_field_datasource.dart';

class DynamicFormFieldRemoteDataSource
    with Loggable, FailureHandler
    implements DynamicFormFieldDataSource {
  @override
  Future<DynamicFormField> get(QueryParams<DynamicFormField> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<DynamicFormField> update(
    UpdateParams<String, DynamicFormFieldPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<DynamicFormField> toggle(
    ToggleParams<String, Field<DynamicFormField, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
