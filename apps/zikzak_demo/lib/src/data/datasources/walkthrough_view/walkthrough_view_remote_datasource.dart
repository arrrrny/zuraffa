// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/walkthrough_view/walkthrough_view.dart';
import 'walkthrough_view_datasource.dart';

class WalkthroughViewRemoteDataSource
    with Loggable, FailureHandler
    implements WalkthroughViewDataSource {
  @override
  Future<WalkthroughView> get(QueryParams<WalkthroughView> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<WalkthroughView> update(
    UpdateParams<String, WalkthroughViewPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<WalkthroughView> toggle(
    ToggleParams<String, Field<WalkthroughView, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
