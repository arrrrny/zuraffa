// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/deal/deal.dart';
import '../../../domain/usecases/deal/get_deal_usecase.dart';
import '../../../domain/usecases/deal/toggle_deal_usecase.dart';
import '../../../domain/usecases/deal/update_deal_usecase.dart';

class DealPresenter extends Presenter {
  DealPresenter() {
    _getDeal = registerUseCase(getIt<GetDealUseCase>());
    _updateDeal = registerUseCase(getIt<UpdateDealUseCase>());
    _toggleDeal = registerUseCase(getIt<ToggleDealUseCase>());
  }

  late final GetDealUseCase _getDeal;

  late final UpdateDealUseCase _updateDeal;

  late final ToggleDealUseCase _toggleDeal;

  Future<Result<Deal, AppFailure>> getDeal(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getDeal.call(
      QueryParams<Deal>(filter: Eq(DealFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Deal, AppFailure>> updateDeal(
    String id,
    DealPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateDeal.call(
      UpdateParams<String, DealPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Deal, AppFailure>> toggleDeal(
    String id,
    Field<Deal, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleDeal.call(
      ToggleParams<String, Field<Deal, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
