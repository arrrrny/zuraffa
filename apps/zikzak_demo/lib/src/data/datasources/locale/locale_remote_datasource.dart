// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/locale/locale.dart';
import 'locale_datasource.dart';

class LocaleRemoteDataSource
    with Loggable, FailureHandler
    implements LocaleDataSource {
  @override
  Future<Locale> get(QueryParams<Locale> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<Locale> update(UpdateParams<String, LocalePatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<Locale> toggle(
    ToggleParams<String, Field<Locale, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
