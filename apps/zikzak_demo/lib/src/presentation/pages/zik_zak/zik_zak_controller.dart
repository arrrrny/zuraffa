// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/zik_zak/zik_zak.dart';
import 'zik_zak_presenter.dart';

class ZikZakController extends Controller {
  ZikZakController(this._presenter);

  final ZikZakPresenter _presenter;

  Future<void> getZikZak(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getZikZak(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateZikZak(
    String id,
    ZikZakPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateZikZak(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleZikZak(
    String id,
    Field<ZikZak, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleZikZak(
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
