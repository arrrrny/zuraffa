import 'package:zuraffa/zuraffa.dart';

import '../../data/engagement_event_repository.dart';
import '../../domain/engagement_event.dart';

/// App-specific hook that records user engagement automatically
/// (bug 501 — spec 011 US3).
///
/// One registration in `main()` replaces every per-controller manual
/// engagement call: whenever a mapped UseCase completes successfully, an
/// [EngagementEvent] is written through the [EngagementEventRepository]
/// (repository-direct pattern — a hook must never call a UseCase, to avoid
/// the infinite recursion documented in spec 011's edge cases).
///
/// Fires on the success phase only: a failing UseCase must not produce an
/// engagement event (criterion C3).
class EngagementHook extends Hook {
  EngagementHook(this._repository);

  final EngagementEventRepository _repository;

  /// Runtime UseCase name → engagement event type.
  ///
  /// Covers all eight ZikZak engagement operations (SC-005):
  /// barcode scan, product search, deal like/share, listing share, link
  /// share, outbound link visit, and Ask ZikZak.
  static const Map<String, EngagementEventType> useCaseEventMap = {
    'CreateBarcodeScanUseCase': EngagementEventType.BARCODE_SCAN,
    'SearchProductsUseCase': EngagementEventType.SEARCH_TERM,
    'LikeDealUseCase': EngagementEventType.DEAL_LIKE,
    'ShareDealUseCase': EngagementEventType.DEAL_SHARE,
    'ShareListingUseCase': EngagementEventType.LISTING_SHARE,
    'ShareLinkUseCase': EngagementEventType.LINK_SHARE,
    'VisitLinkUseCase': EngagementEventType.VISIT_LINK,
    'AskZikZakUseCase': EngagementEventType.ASK_ZIKZAK,
  };

  @override
  String get id => 'zikzak-engagement';

  /// Runs after the built-in TelemetryHook (default priority 0) so the
  /// OTel span exists before engagement side effects run.
  @override
  int get priority => 10;

  /// Success-only: engagement is recorded for completed operations (C3).
  @override
  Set<HookPhase> get phases => const {HookPhase.success};

  @override
  bool shouldTrigger(HookContext context, HookPhase phase) =>
      useCaseEventMap.containsKey(context.useCaseName);

  @override
  Future<void> execute(HookContext context, HookPhase phase) async {
    final type = useCaseEventMap[context.useCaseName];
    if (type == null) return;

    await _repository.create(
      EngagementEvent(
        id: _eventId(context),
        type: type,
        payload: payloadFor(context.useCaseName, context.params),
        createdAt: context.timestamp,
      ),
    );
  }

  /// Extracts the engagement payload from the UseCase params per UseCase
  /// type: plain-string params pass through, share-style params contribute
  /// their subject id.
  static String payloadFor(String useCaseName, Object? params) {
    if (useCaseName == 'ShareDealUseCase' ||
        useCaseName == 'ShareListingUseCase' ||
        useCaseName == 'ShareLinkUseCase') {
      return params is ({String subjectId, String channel})
          ? params.subjectId
          : '';
    }
    return params is String ? params : '';
  }

  static String _eventId(HookContext context) =>
      '${context.useCaseName}-${context.timestamp.microsecondsSinceEpoch}';
}
