// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/zik_zak_score/zik_zak_score.dart';
import 'zik_zak_score_datasource.dart';

class ZikZakScoreRemoteDataSource
    with Loggable, FailureHandler
    implements ZikZakScoreDataSource {
  @override
  Future<ZikZakScore> get(QueryParams<ZikZakScore> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<ZikZakScore> update(
    UpdateParams<String, ZikZakScorePatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<ZikZakScore> toggle(
    ToggleParams<String, Field<ZikZakScore, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
