/// Shared fakes for the refactor pass-registry suites.
///
/// The fake executor, its programmed outcome and the `print` capture had
/// been copied per suite (`refactor_passes_test.dart`,
/// `bug_1472_refactor_gate_errors_only_test.dart`) — the #1572 review
/// flagged the drift risk, so they live here.
library;

import 'dart:async';

import 'package:zuraffa/src/plugins/tdd/services/refactor_passes.dart';

/// A fake process executor that records every invocation and returns
/// programmed outcomes in order.
class FakeProcessExecutor implements ProcessExecutor {
  FakeProcessExecutor(this._outcomes);

  final List<ProgrammedOutcome> _outcomes;
  int _next = 0;
  final List<RefactorPassInvocation> invocations = [];

  @override
  Future<ProcessRunOutcome> run(RefactorPassInvocation inv) async {
    invocations.add(inv);
    if (_next >= _outcomes.length) {
      return ProcessRunOutcome(
        command: inv.command,
        exitCode: 0,
        output: '(default success)',
        startedProcess: true,
      );
    }
    final programmed = _outcomes[_next++];
    return ProcessRunOutcome(
      command: inv.command,
      exitCode: programmed.exitCode,
      output: programmed.output,
      startedProcess: programmed.startedProcess,
      timedOut: programmed.timedOut,
    );
  }
}

/// One programmed pass outcome, consumed in order by [FakeProcessExecutor].
class ProgrammedOutcome {
  ProgrammedOutcome({
    required this.exitCode,
    required this.output,
    this.startedProcess = true,
    this.timedOut = false,
  });

  final int exitCode;
  final String output;
  final bool startedProcess;
  final bool timedOut;
}

/// Capture `print` output inside [body] (the registry logs the tolerated
/// verdict through `print`).
Future<(T, List<String>)> capturePrint<T>(Future<T> Function() body) async {
  final lines = <String>[];
  late final T result;
  await runZoned(
    () async {
      result = await body();
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        lines.add(line);
      },
    ),
  );
  return (result, lines);
}
