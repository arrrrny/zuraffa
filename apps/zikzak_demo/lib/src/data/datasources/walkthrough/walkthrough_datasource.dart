// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/walkthrough/walkthrough.dart';

abstract class WalkthroughDataSource with Loggable, FailureHandler {
  Future<Walkthrough> get(QueryParams<Walkthrough> params);
  Future<Walkthrough> update(UpdateParams<String, WalkthroughPatch> params);
  Future<Walkthrough> toggle(
    ToggleParams<String, Field<Walkthrough, dynamic>> params,
  );
}

// END GENERATED
