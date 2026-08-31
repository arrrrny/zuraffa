import 'package:zuraffa/zuraffa.dart';

import '../../../domain/usecases/engagement_usecases.dart';

/// Reusable share button component.
///
/// Engagement capture is automated by the EngagementHook registered in
/// main() — components carry no manual engagement call sites (C5).
class ShareButton {
  ShareButton(this._shareLink, this._shareListing);

  final ShareLinkUseCase _shareLink;
  final ShareListingUseCase _shareListing;

  /// Shares [url] over [channel].
  Future<Result<void, AppFailure>> shareLink(String url, String channel) =>
      _shareLink((subjectId: url, channel: channel));

  /// Shares [listingId] over [channel].
  Future<Result<void, AppFailure>> shareListing(
    String listingId,
    String channel,
  ) => _shareListing((subjectId: listingId, channel: channel));
}
