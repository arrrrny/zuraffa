// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/zik_zak_config/zik_zak_config.dart';
import 'zik_zak_config_presenter.dart';

class ZikZakConfigController extends Controller {
  ZikZakConfigController(this._presenter);

  final ZikZakConfigPresenter _presenter;

  Future<void> getZikZakConfig(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getZikZakConfig(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateZikZakConfig(
    String id,
    ZikZakConfigPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateZikZakConfig(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleZikZakConfig(
    String id,
    Field<ZikZakConfig, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleZikZakConfig(
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
