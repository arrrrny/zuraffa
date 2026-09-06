// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/walkthrough_step/walkthrough_step.dart';
import 'walkthrough_step_presenter.dart';

class WalkthroughStepController extends Controller {
  WalkthroughStepController(this._presenter);

  final WalkthroughStepPresenter _presenter;

  Future<void> getWalkthroughStep(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getWalkthroughStep(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateWalkthroughStep(
    String id,
    WalkthroughStepPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateWalkthroughStep(
      id,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleWalkthroughStep(
    String id,
    Field<WalkthroughStep, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleWalkthroughStep(
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
