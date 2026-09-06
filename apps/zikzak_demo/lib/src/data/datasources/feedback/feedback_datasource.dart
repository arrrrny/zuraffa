// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/feedback/feedback.dart';

abstract class FeedbackDataSource with Loggable, FailureHandler {
  Future<Feedback> get(QueryParams<Feedback> params);
  Future<Feedback> update(UpdateParams<String, FeedbackPatch> params);
  Future<Feedback> toggle(
    ToggleParams<String, Field<Feedback, dynamic>> params,
  );
}

// END GENERATED
