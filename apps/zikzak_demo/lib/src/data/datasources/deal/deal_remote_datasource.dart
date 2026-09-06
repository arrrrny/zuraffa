// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/deal/deal.dart';
import 'deal_datasource.dart';

class DealRemoteDataSource
    with Loggable, FailureHandler
    implements DealDataSource {
  @override
  Future<Deal> get(QueryParams<Deal> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<Deal> update(UpdateParams<String, DealPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<Deal> toggle(ToggleParams<String, Field<Deal, dynamic>> params) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
