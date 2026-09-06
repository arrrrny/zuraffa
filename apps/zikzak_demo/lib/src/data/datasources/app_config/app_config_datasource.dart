// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/app_config/app_config.dart';

abstract class AppConfigDataSource with Loggable, FailureHandler {
  Future<AppConfig> get(QueryParams<AppConfig> params);
  Future<AppConfig> update(UpdateParams<String, AppConfigPatch> params);
  Future<AppConfig> toggle(
    ToggleParams<String, Field<AppConfig, dynamic>> params,
  );
}

// END GENERATED
