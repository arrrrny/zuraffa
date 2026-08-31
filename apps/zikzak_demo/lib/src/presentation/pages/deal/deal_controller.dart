import 'package:zuraffa/zuraffa.dart';

import '../../../domain/usecases/engagement_usecases.dart';

/// Controller for the deal page.
///
/// Engagement capture is automated by the EngagementHook registered in
/// main() — controllers carry no manual engagement call sites (C5).
class DealController {
  DealController(this._likeDeal, this._shareDeal);

  final LikeDealUseCase _likeDeal;
  final ShareDealUseCase _shareDeal;

  /// Likes [dealId] through the deal-like UseCase.
  Future<Result<void, AppFailure>> like(String dealId) => _likeDeal(dealId);

  /// Shares [dealId] over [channel] through the deal-share UseCase.
  Future<Result<void, AppFailure>> share(String dealId, String channel) =>
      _shareDeal((subjectId: dealId, channel: channel));
}
