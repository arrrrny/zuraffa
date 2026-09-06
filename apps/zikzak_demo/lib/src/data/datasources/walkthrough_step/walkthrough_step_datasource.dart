// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/walkthrough_step/walkthrough_step.dart';

abstract class WalkthroughStepDataSource with Loggable, FailureHandler {
  Future<WalkthroughStep> get(QueryParams<WalkthroughStep> params);
  Future<WalkthroughStep> update(
    UpdateParams<String, WalkthroughStepPatch> params,
  );
  Future<WalkthroughStep> toggle(
    ToggleParams<String, Field<WalkthroughStep, dynamic>> params,
  );
}

// END GENERATED
