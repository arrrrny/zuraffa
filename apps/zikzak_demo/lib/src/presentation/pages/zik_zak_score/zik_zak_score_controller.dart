// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/zik_zak_score/zik_zak_score.dart';
import 'zik_zak_score_presenter.dart';

class ZikZakScoreController extends Controller {
  ZikZakScoreController(this._presenter);

  final ZikZakScorePresenter _presenter;

  Future<void> getZikZakScore(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getZikZakScore(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateZikZakScore(
    String id,
    ZikZakScorePatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateZikZakScore(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleZikZakScore(
    String id,
    Field<ZikZakScore, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleZikZakScore(
      id,
      field,
      toggleValue,
      cancelToken,
    );
    result.fold((toggled) {}, (failure) {});
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}

// END GENERATED
