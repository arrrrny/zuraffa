// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/zik_zak_config/zik_zak_config.dart';

abstract class ZikZakConfigDataSource with Loggable, FailureHandler {
  Future<ZikZakConfig> get(QueryParams<ZikZakConfig> params);
  Future<ZikZakConfig> update(UpdateParams<String, ZikZakConfigPatch> params);
  Future<ZikZakConfig> toggle(
    ToggleParams<String, Field<ZikZakConfig, dynamic>> params,
  );
}

// END GENERATED
