/// The eight ZikZak engagement UseCases (mock app — bug 501 remediation).
///
/// One UseCase per [EngagementEventType] value: the EngagementHook maps these
/// runtime type names to event types (see
/// `presentation/hooks/engagement_hook.dart`).
library;

import 'package:zuraffa/zuraffa.dart';

/// Shared params record for the share-style UseCases.
typedef ShareIntent = ({String subjectId, String channel});

/// Barcode scan — maps to `BARCODE_SCAN`; params is the scanned number.
class CreateBarcodeScanUseCase extends UseCase<String, String> {
  @override
  Future<String> execute(String params, CancelToken? cancelToken) async {
    if (params.isEmpty) {
      throw ValidationFailure('Barcode number must not be empty');
    }
    return 'scanned:$params';
  }
}

/// Product search — maps to `SEARCH_TERM`; params is the raw query string.
class SearchProductsUseCase extends UseCase<List<String>, String> {
  static const _catalog = <String>[
    'zikrarex starter kit',
    'zikzak pro plan',
    'clean architecture guide',
  ];

  @override
  Future<List<String>> execute(String params, CancelToken? cancelToken) async {
    if (params.trim().isEmpty) {
      throw ValidationFailure('Search query must not be empty');
    }
    final query = params.toLowerCase();
    return _catalog.where((item) => item.contains(query)).toList();
  }
}

/// Deal like — maps to `DEAL_LIKE`; params is the deal id.
class LikeDealUseCase extends UseCase<void, String> {
  @override
  Future<void> execute(String params, CancelToken? cancelToken) async {
    if (params.isEmpty) {
      throw ValidationFailure('Deal id must not be empty');
    }
  }
}

/// Deal share — maps to `DEAL_SHARE`; params carries the deal id + channel.
class ShareDealUseCase extends UseCase<void, ShareIntent> {
  @override
  Future<void> execute(ShareIntent params, CancelToken? cancelToken) async {
    if (params.subjectId.isEmpty) {
      throw ValidationFailure('Deal id must not be empty');
    }
  }
}

/// Listing share — maps to `LISTING_SHARE`; params carries listing id + channel.
class ShareListingUseCase extends UseCase<void, ShareIntent> {
  @override
  Future<void> execute(ShareIntent params, CancelToken? cancelToken) async {
    if (params.subjectId.isEmpty) {
      throw ValidationFailure('Listing id must not be empty');
    }
  }
}

/// Link share — maps to `LINK_SHARE`; params carries the url + channel.
class ShareLinkUseCase extends UseCase<void, ShareIntent> {
  @override
  Future<void> execute(ShareIntent params, CancelToken? cancelToken) async {
    if (params.subjectId.isEmpty) {
      throw ValidationFailure('Link url must not be empty');
    }
  }
}

/// Outbound link visit — maps to `VISIT_LINK`; params is the target url.
class VisitLinkUseCase extends UseCase<void, String> {
  @override
  Future<void> execute(String params, CancelToken? cancelToken) async {
    if (params.isEmpty) {
      throw ValidationFailure('Link url must not be empty');
    }
  }
}

/// Ask ZikZak assistant — maps to `ASK_ZIKZAK`; params is the question.
class AskZikZakUseCase extends UseCase<String, String> {
  @override
  Future<String> execute(String params, CancelToken? cancelToken) async {
    if (params.trim().isEmpty) {
      throw ValidationFailure('Question must not be empty');
    }
    return 'answer:$params';
  }
}
