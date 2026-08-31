import 'package:zuraffa/zuraffa.dart';

import 'src/data/engagement_event_repository.dart';

/// ZikZak mock app bootstrap (bug 501).
///
/// RED phase: only the repository is wired. The EngagementHook registration
/// lands here in the green phase — one hook registration will replace every
/// per-controller manual engagement call.
Future<void> main() async {
  final engagementRepository = EngagementEventRepository();
  await engagementRepository.init();

  // Built-in OTel tracing for every UseCase (framework US2, ships with
  // the framework).
  HookRegistry.instance.register(TelemetryHook());

  // GREEN phase adds:
  // HookRegistry.instance.register(EngagementHook(engagementRepository));

  // The real ZikZak app would runApp(...) here; this mock exists solely to
  // validate US3 acceptance scenarios C1–C5 of spec 011.
}
