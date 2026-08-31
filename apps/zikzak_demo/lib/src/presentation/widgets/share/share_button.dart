import 'dart:async';

import 'package:zuraffa/zuraffa.dart';

import '../../domain/usecases/engagement_usecases.dart';
import '../../telemetry/create_telemetry_event_use_case.dart';

/// Reusable share button component (RED — manual calls present).
class ShareButton {
  ShareButton(this._shareLink, this._shareListing, this._telemetry);

  final ShareLinkUseCase _shareLink;
  final ShareListingUseCase _shareListing;
  final CreateTelemetryEventUseCase _telemetry;

  /// Shares [url] over [channel].
  Future<Result<void, AppFailure>> shareLink(
    String url,
    String channel,
  ) async {
    final result = await _shareLink((subjectId: url, channel: channel));
    result.fold(
      (_) => _trackLinkShared(url),
      (_) {},
    );
    return result;
  }

  /// Shares [listingId] over [channel].
  Future<Result<void, AppFailure>> shareListing(
    String listingId,
    String channel,
  ) async {
    final result = await _shareListing((subjectId: listingId, channel: channel));
    result.fold(
      (_) => _trackListingShared(listingId),
      (_) {},
    );
    return result;
  }

  void _trackLinkShared(String url) {
    unawaited(
      _telemetry.call(<String, dynamic>{'event': 'LINK_SHARE', 'payload': url}),
    );
  }

  void _trackListingShared(String listingId) {
    unawaited(
      _telemetry.call(<String, dynamic>{'event': 'LISTING_SHARE', 'payload': listingId}),
    );
  }
}
