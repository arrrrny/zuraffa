// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/app_config/app_config.dart';
import 'app_config_datasource.dart';

class AppConfigRemoteDataSource
    with Loggable, FailureHandler
    implements AppConfigDataSource {
  @override
  Future<AppConfig> get(QueryParams<AppConfig> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<AppConfig> update(UpdateParams<String, AppConfigPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<AppConfig> toggle(
    ToggleParams<String, Field<AppConfig, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
