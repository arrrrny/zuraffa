// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/zik_zak_score/zik_zak_score.dart';
import '../../../domain/usecases/zik_zak_score/get_zik_zak_score_usecase.dart';
import '../../../domain/usecases/zik_zak_score/toggle_zik_zak_score_usecase.dart';
import '../../../domain/usecases/zik_zak_score/update_zik_zak_score_usecase.dart';

class ZikZakScorePresenter extends Presenter {
  ZikZakScorePresenter() {
    _getZikZakScore = registerUseCase(getIt<GetZikZakScoreUseCase>());
    _updateZikZakScore = registerUseCase(getIt<UpdateZikZakScoreUseCase>());
    _toggleZikZakScore = registerUseCase(getIt<ToggleZikZakScoreUseCase>());
  }

  late final GetZikZakScoreUseCase _getZikZakScore;

  late final UpdateZikZakScoreUseCase _updateZikZakScore;

  late final ToggleZikZakScoreUseCase _toggleZikZakScore;

  Future<Result<ZikZakScore, AppFailure>> getZikZakScore(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getZikZakScore.call(
      QueryParams<ZikZakScore>(filter: Eq(ZikZakScoreFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ZikZakScore, AppFailure>> updateZikZakScore(
    String id,
    ZikZakScorePatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateZikZakScore.call(
      UpdateParams<String, ZikZakScorePatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ZikZakScore, AppFailure>> toggleZikZakScore(
    String id,
    Field<ZikZakScore, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleZikZakScore.call(
      ToggleParams<String, Field<ZikZakScore, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
