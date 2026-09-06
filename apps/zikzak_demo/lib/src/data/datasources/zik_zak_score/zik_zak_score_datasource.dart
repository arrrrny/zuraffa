// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/zik_zak_score/zik_zak_score.dart';

abstract class ZikZakScoreDataSource with Loggable, FailureHandler {
  Future<ZikZakScore> get(QueryParams<ZikZakScore> params);
  Future<ZikZakScore> update(UpdateParams<String, ZikZakScorePatch> params);
  Future<ZikZakScore> toggle(
    ToggleParams<String, Field<ZikZakScore, dynamic>> params,
  );
}

// END GENERATED
