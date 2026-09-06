// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/form_option/form_option.dart';
import 'form_option_datasource.dart';

class FormOptionRemoteDataSource
    with Loggable, FailureHandler
    implements FormOptionDataSource {
  @override
  Future<FormOption> get(QueryParams<FormOption> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<FormOption> update(
    UpdateParams<String, FormOptionPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<FormOption> toggle(
    ToggleParams<String, Field<FormOption, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
