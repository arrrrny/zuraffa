// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/walkthrough/walkthrough.dart';
import 'walkthrough_datasource.dart';

class WalkthroughRemoteDataSource
    with Loggable, FailureHandler
    implements WalkthroughDataSource {
  @override
  Future<Walkthrough> get(QueryParams<Walkthrough> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<Walkthrough> update(
    UpdateParams<String, WalkthroughPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<Walkthrough> toggle(
    ToggleParams<String, Field<Walkthrough, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
