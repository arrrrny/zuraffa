// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/locale/locale.dart';

abstract class LocaleDataSource with Loggable, FailureHandler {
  Future<Locale> get(QueryParams<Locale> params);
  Future<Locale> update(UpdateParams<String, LocalePatch> params);
  Future<Locale> toggle(ToggleParams<String, Field<Locale, dynamic>> params);
}

// END GENERATED
