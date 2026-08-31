import 'package:zuraffa/zuraffa.dart';

import 'src/data/engagement_event_repository.dart';
import 'src/presentation/hooks/engagement_hook.dart';

/// ZikZak mock app bootstrap (bug 501).
///
/// Engagement capture is fully automated through the hook system: the single
/// [EngagementHook] registration below replaces all per-controller manual
/// engagement calls (spec 011 US3, criterion C5).
Future<void> main() async {
  final engagementRepository = EngagementEventRepository();
  await engagementRepository.init();

  // Built-in OTel tracing for every UseCase (framework US2 — ships with the
  // framework). Coexists with the engagement hook (C4).
  HookRegistry.instance.register(TelemetryHook());

  // App-specific engagement capture — success-only, repository-direct (C1-C4).
  HookRegistry.instance.register(EngagementHook(engagementRepository));

  // The real ZikZak app would runApp(...) here; this mock exists solely to
  // validate US3 acceptance scenarios C1–C5 of spec 011.
}
