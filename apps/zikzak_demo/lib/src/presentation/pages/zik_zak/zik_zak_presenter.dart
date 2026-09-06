// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/zik_zak/zik_zak.dart';
import '../../../domain/usecases/zik_zak/get_zik_zak_usecase.dart';
import '../../../domain/usecases/zik_zak/toggle_zik_zak_usecase.dart';
import '../../../domain/usecases/zik_zak/update_zik_zak_usecase.dart';

class ZikZakPresenter extends Presenter {
  ZikZakPresenter() {
    _getZikZak = registerUseCase(getIt<GetZikZakUseCase>());
    _updateZikZak = registerUseCase(getIt<UpdateZikZakUseCase>());
    _toggleZikZak = registerUseCase(getIt<ToggleZikZakUseCase>());
  }

  late final GetZikZakUseCase _getZikZak;

  late final UpdateZikZakUseCase _updateZikZak;

  late final ToggleZikZakUseCase _toggleZikZak;

  Future<Result<ZikZak, AppFailure>> getZikZak(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getZikZak.call(
      QueryParams<ZikZak>(filter: Eq(ZikZakFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ZikZak, AppFailure>> updateZikZak(
    String id,
    ZikZakPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateZikZak.call(
      UpdateParams<String, ZikZakPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ZikZak, AppFailure>> toggleZikZak(
    String id,
    Field<ZikZak, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleZikZak.call(
      ToggleParams<String, Field<ZikZak, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
