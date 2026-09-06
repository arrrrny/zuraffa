// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/walkthrough_view/walkthrough_view.dart';
import '../../../domain/usecases/walkthrough_view/get_walkthrough_view_usecase.dart';
import '../../../domain/usecases/walkthrough_view/toggle_walkthrough_view_usecase.dart';
import '../../../domain/usecases/walkthrough_view/update_walkthrough_view_usecase.dart';

class WalkthroughViewPresenter extends Presenter {
  WalkthroughViewPresenter() {
    _getWalkthroughView = registerUseCase(getIt<GetWalkthroughViewUseCase>());
    _updateWalkthroughView = registerUseCase(
      getIt<UpdateWalkthroughViewUseCase>(),
    );
    _toggleWalkthroughView = registerUseCase(
      getIt<ToggleWalkthroughViewUseCase>(),
    );
  }

  late final GetWalkthroughViewUseCase _getWalkthroughView;

  late final UpdateWalkthroughViewUseCase _updateWalkthroughView;

  late final ToggleWalkthroughViewUseCase _toggleWalkthroughView;

  Future<Result<WalkthroughView, AppFailure>> getWalkthroughView(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getWalkthroughView.call(
      QueryParams<WalkthroughView>(filter: Eq(WalkthroughViewFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<WalkthroughView, AppFailure>> updateWalkthroughView(
    String id,
    WalkthroughViewPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateWalkthroughView.call(
      UpdateParams<String, WalkthroughViewPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<WalkthroughView, AppFailure>> toggleWalkthroughView(
    String id,
    Field<WalkthroughView, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleWalkthroughView.call(
      ToggleParams<String, Field<WalkthroughView, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
