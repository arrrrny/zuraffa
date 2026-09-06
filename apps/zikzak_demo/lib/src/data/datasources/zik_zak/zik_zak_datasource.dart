// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/zik_zak/zik_zak.dart';

abstract class ZikZakDataSource with Loggable, FailureHandler {
  Future<ZikZak> get(QueryParams<ZikZak> params);
  Future<ZikZak> update(UpdateParams<String, ZikZakPatch> params);
  Future<ZikZak> toggle(ToggleParams<String, Field<ZikZak, dynamic>> params);
}

// END GENERATED
