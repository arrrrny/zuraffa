// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/dynamic_form/dynamic_form.dart';
import 'dynamic_form_datasource.dart';

class DynamicFormRemoteDataSource
    with Loggable, FailureHandler
    implements DynamicFormDataSource {
  @override
  Future<DynamicForm> get(QueryParams<DynamicForm> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<DynamicForm> update(
    UpdateParams<String, DynamicFormPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<DynamicForm> toggle(
    ToggleParams<String, Field<DynamicForm, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
