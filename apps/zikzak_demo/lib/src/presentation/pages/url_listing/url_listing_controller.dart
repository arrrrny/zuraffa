import 'package:zuraffa/zuraffa.dart';

import '../../../domain/usecases/engagement_usecases.dart';

/// Controller for the outbound url listing page.
///
/// Engagement capture is automated by the EngagementHook registered in
/// main() — controllers carry no manual engagement call sites (C5).
class UrlListingController {
  UrlListingController(this._visitLink);

  final VisitLinkUseCase _visitLink;

  /// Navigates to [url] through the outbound-link UseCase.
  Future<Result<void, AppFailure>> open(String url) => _visitLink(url);
}
