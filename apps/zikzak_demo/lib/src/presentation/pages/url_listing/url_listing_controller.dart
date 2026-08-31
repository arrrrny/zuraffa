import 'dart:async';

import 'package:zuraffa/zuraffa.dart';

import '../../../domain/usecases/engagement_usecases.dart';
import '../../../telemetry/create_telemetry_event_use_case.dart';

/// Controller for the outbound url listing page (RED — manual call present).
class UrlListingController {
  UrlListingController(this._visitLink, this._telemetry);

  final VisitLinkUseCase _visitLink;
  final CreateTelemetryEventUseCase _telemetry;

  /// Navigates to [url] through the outbound-link UseCase.
  Future<Result<void, AppFailure>> open(String url) async {
    final result = await _visitLink(url);
    result.fold(
      (_) => _trackLinkVisited(url),
      (_) {},
    );
    return result;
  }

  void _trackLinkVisited(String url) {
    unawaited(
      _telemetry.call(<String, dynamic>{'event': 'VISIT_LINK', 'payload': url}),
    );
  }
}
