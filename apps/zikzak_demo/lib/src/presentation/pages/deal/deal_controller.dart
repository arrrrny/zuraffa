import 'dart:async';

import 'package:zuraffa/zuraffa.dart';

import '../../../domain/usecases/engagement_usecases.dart';
import '../../../telemetry/create_telemetry_event_use_case.dart';

/// Controller for the deal page (RED — manual calls present).
class DealController {
  DealController(this._likeDeal, this._shareDeal, this._telemetry);

  final LikeDealUseCase _likeDeal;
  final ShareDealUseCase _shareDeal;
  final CreateTelemetryEventUseCase _telemetry;

  /// Likes [dealId] through the deal-like UseCase.
  Future<Result<void, AppFailure>> like(String dealId) async {
    final result = await _likeDeal(dealId);
    result.fold(
      (_) => _trackDealLiked(dealId),
      (_) {},
    );
    return result;
  }

  /// Shares [dealId] over [channel] through the deal-share UseCase.
  Future<Result<void, AppFailure>> share(String dealId, String channel) async {
    final result = await _shareDeal((subjectId: dealId, channel: channel));
    result.fold(
      (_) => _trackDealShared(dealId),
      (_) {},
    );
    return result;
  }

  void _trackDealLiked(String dealId) {
    unawaited(
      _telemetry.call(<String, dynamic>{'event': 'DEAL_LIKE', 'payload': dealId}),
    );
  }

  void _trackDealShared(String dealId) {
    unawaited(
      _telemetry.call(<String, dynamic>{'event': 'DEAL_SHARE', 'payload': dealId}),
    );
  }
}
