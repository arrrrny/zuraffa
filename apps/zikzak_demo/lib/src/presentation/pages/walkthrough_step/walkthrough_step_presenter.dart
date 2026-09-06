// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/walkthrough_step/walkthrough_step.dart';
import '../../../domain/usecases/walkthrough_step/get_walkthrough_step_usecase.dart';
import '../../../domain/usecases/walkthrough_step/toggle_walkthrough_step_usecase.dart';
import '../../../domain/usecases/walkthrough_step/update_walkthrough_step_usecase.dart';

class WalkthroughStepPresenter extends Presenter {
  WalkthroughStepPresenter() {
    _getWalkthroughStep = registerUseCase(getIt<GetWalkthroughStepUseCase>());
    _updateWalkthroughStep = registerUseCase(
      getIt<UpdateWalkthroughStepUseCase>(),
    );
    _toggleWalkthroughStep = registerUseCase(
      getIt<ToggleWalkthroughStepUseCase>(),
    );
  }

  late final GetWalkthroughStepUseCase _getWalkthroughStep;

  late final UpdateWalkthroughStepUseCase _updateWalkthroughStep;

  late final ToggleWalkthroughStepUseCase _toggleWalkthroughStep;

  Future<Result<WalkthroughStep, AppFailure>> getWalkthroughStep(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getWalkthroughStep.call(
      QueryParams<WalkthroughStep>(filter: Eq(WalkthroughStepFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<WalkthroughStep, AppFailure>> updateWalkthroughStep(
    String id,
    WalkthroughStepPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateWalkthroughStep.call(
      UpdateParams<String, WalkthroughStepPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<WalkthroughStep, AppFailure>> toggleWalkthroughStep(
    String id,
    Field<WalkthroughStep, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleWalkthroughStep.call(
      ToggleParams<String, Field<WalkthroughStep, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
