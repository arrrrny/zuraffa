// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/walkthrough_view/walkthrough_view.dart';
import 'walkthrough_view_presenter.dart';

class WalkthroughViewController extends Controller {
  WalkthroughViewController(this._presenter);

  final WalkthroughViewPresenter _presenter;

  Future<void> getWalkthroughView(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getWalkthroughView(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateWalkthroughView(
    String id,
    WalkthroughViewPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateWalkthroughView(
      id,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleWalkthroughView(
    String id,
    Field<WalkthroughView, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleWalkthroughView(
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
