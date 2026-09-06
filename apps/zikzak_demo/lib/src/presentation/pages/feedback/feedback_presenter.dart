// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/feedback/feedback.dart';
import '../../../domain/usecases/feedback/get_feedback_usecase.dart';
import '../../../domain/usecases/feedback/toggle_feedback_usecase.dart';
import '../../../domain/usecases/feedback/update_feedback_usecase.dart';

class FeedbackPresenter extends Presenter {
  FeedbackPresenter() {
    _getFeedback = registerUseCase(getIt<GetFeedbackUseCase>());
    _updateFeedback = registerUseCase(getIt<UpdateFeedbackUseCase>());
    _toggleFeedback = registerUseCase(getIt<ToggleFeedbackUseCase>());
  }

  late final GetFeedbackUseCase _getFeedback;

  late final UpdateFeedbackUseCase _updateFeedback;

  late final ToggleFeedbackUseCase _toggleFeedback;

  Future<Result<Feedback, AppFailure>> getFeedback(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getFeedback.call(
      QueryParams<Feedback>(filter: Eq(FeedbackFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Feedback, AppFailure>> updateFeedback(
    String id,
    FeedbackPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateFeedback.call(
      UpdateParams<String, FeedbackPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Feedback, AppFailure>> toggleFeedback(
    String id,
    Field<Feedback, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleFeedback.call(
      ToggleParams<String, Field<Feedback, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
