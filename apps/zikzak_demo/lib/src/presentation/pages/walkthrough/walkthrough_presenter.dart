// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/walkthrough/walkthrough.dart';
import '../../../domain/usecases/walkthrough/get_walkthrough_usecase.dart';
import '../../../domain/usecases/walkthrough/toggle_walkthrough_usecase.dart';
import '../../../domain/usecases/walkthrough/update_walkthrough_usecase.dart';

class WalkthroughPresenter extends Presenter {
  WalkthroughPresenter() {
    _getWalkthrough = registerUseCase(getIt<GetWalkthroughUseCase>());
    _updateWalkthrough = registerUseCase(getIt<UpdateWalkthroughUseCase>());
    _toggleWalkthrough = registerUseCase(getIt<ToggleWalkthroughUseCase>());
  }

  late final GetWalkthroughUseCase _getWalkthrough;

  late final UpdateWalkthroughUseCase _updateWalkthrough;

  late final ToggleWalkthroughUseCase _toggleWalkthrough;

  Future<Result<Walkthrough, AppFailure>> getWalkthrough(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getWalkthrough.call(
      QueryParams<Walkthrough>(filter: Eq(WalkthroughFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Walkthrough, AppFailure>> updateWalkthrough(
    String id,
    WalkthroughPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateWalkthrough.call(
      UpdateParams<String, WalkthroughPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Walkthrough, AppFailure>> toggleWalkthrough(
    String id,
    Field<Walkthrough, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleWalkthrough.call(
      ToggleParams<String, Field<Walkthrough, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
