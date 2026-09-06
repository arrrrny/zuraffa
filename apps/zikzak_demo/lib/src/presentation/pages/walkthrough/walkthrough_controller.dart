// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/walkthrough/walkthrough.dart';
import 'walkthrough_presenter.dart';

class WalkthroughController extends Controller {
  WalkthroughController(this._presenter);

  final WalkthroughPresenter _presenter;

  Future<void> getWalkthrough(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getWalkthrough(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateWalkthrough(
    String id,
    WalkthroughPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateWalkthrough(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleWalkthrough(
    String id,
    Field<Walkthrough, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleWalkthrough(
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
