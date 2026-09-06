// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/feedback/feedback.dart';
import 'feedback_presenter.dart';

class FeedbackController extends Controller {
  FeedbackController(this._presenter);

  final FeedbackPresenter _presenter;

  Future<void> getFeedback(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getFeedback(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateFeedback(
    String id,
    FeedbackPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateFeedback(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleFeedback(
    String id,
    Field<Feedback, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleFeedback(
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
