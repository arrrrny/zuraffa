// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/zik_zak/zik_zak.dart';
import 'zik_zak_datasource.dart';

class ZikZakRemoteDataSource
    with Loggable, FailureHandler
    implements ZikZakDataSource {
  @override
  Future<ZikZak> get(QueryParams<ZikZak> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<ZikZak> update(UpdateParams<String, ZikZakPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<ZikZak> toggle(
    ToggleParams<String, Field<ZikZak, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
