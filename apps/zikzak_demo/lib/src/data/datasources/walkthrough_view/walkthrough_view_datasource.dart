// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/walkthrough_view/walkthrough_view.dart';

abstract class WalkthroughViewDataSource with Loggable, FailureHandler {
  Future<WalkthroughView> get(QueryParams<WalkthroughView> params);
  Future<WalkthroughView> update(
    UpdateParams<String, WalkthroughViewPatch> params,
  );
  Future<WalkthroughView> toggle(
    ToggleParams<String, Field<WalkthroughView, dynamic>> params,
  );
}

// END GENERATED
