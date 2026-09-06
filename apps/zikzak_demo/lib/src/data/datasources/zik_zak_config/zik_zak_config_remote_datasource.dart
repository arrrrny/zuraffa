// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/zik_zak_config/zik_zak_config.dart';
import 'zik_zak_config_datasource.dart';

class ZikZakConfigRemoteDataSource
    with Loggable, FailureHandler
    implements ZikZakConfigDataSource {
  @override
  Future<ZikZakConfig> get(QueryParams<ZikZakConfig> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<ZikZakConfig> update(
    UpdateParams<String, ZikZakConfigPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<ZikZakConfig> toggle(
    ToggleParams<String, Field<ZikZakConfig, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
