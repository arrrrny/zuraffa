/// Legacy manual engagement sink (RED phase of bug 501 — removed in green).
///
/// Before the hook-based approach, every ZikZak controller invoked this
/// UseCase by hand after a successful operation. Bug 501 replaces all of
/// those call sites with a single EngagementHook registration; this class is
/// deleted together with its call sites in the green phase.
library;

import 'package:zuraffa/zuraffa.dart';

/// Manual telemetry event creation — the pre-hook mechanism.
class CreateTelemetryEventUseCase extends UseCase<void, Map<String, dynamic>> {
  CreateTelemetryEventUseCase({void Function(Map<String, dynamic> event)? sink})
      : _sink = sink ?? (_) {};

  final void Function(Map<String, dynamic> event) _sink;

  @override
  Future<void> execute(
    Map<String, dynamic> params,
    CancelToken? cancelToken,
  ) async {
    _sink(params);
  }
}
