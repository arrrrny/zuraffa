// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/walkthrough_step/walkthrough_step.dart';
import 'walkthrough_step_datasource.dart';

class WalkthroughStepRemoteDataSource
    with Loggable, FailureHandler
    implements WalkthroughStepDataSource {
  @override
  Future<WalkthroughStep> get(QueryParams<WalkthroughStep> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<WalkthroughStep> update(
    UpdateParams<String, WalkthroughStepPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<WalkthroughStep> toggle(
    ToggleParams<String, Field<WalkthroughStep, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
