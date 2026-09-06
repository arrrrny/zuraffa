// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/feedback/feedback.dart';
import 'feedback_datasource.dart';

class FeedbackRemoteDataSource
    with Loggable, FailureHandler
    implements FeedbackDataSource {
  @override
  Future<Feedback> get(QueryParams<Feedback> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<Feedback> update(UpdateParams<String, FeedbackPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<Feedback> toggle(
    ToggleParams<String, Field<Feedback, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
