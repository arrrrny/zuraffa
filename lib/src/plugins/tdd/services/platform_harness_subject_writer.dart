/// PlatformHarnessSubjectWriter — emits the platform-channel subject stub
/// for a `platform`-kind behavior (issue #831 — platform-channel test
/// harness).
///
/// The emitted subject is the honest-red half of the gen pair:
///
///   - a `MethodChannel` const bound to the channel named by the
///     behavior's committed scenario (single source of truth: intent);
///   - the behavior's subject function, which throws
///     `UnimplementedError` until wired — the paired harness test
///     captures it into an ASSERTION failure (honest red), then, once
///     implemented, every channel call the subject makes is recorded by
///     the certified fake so the tests assert on observed calls.
///
/// The emitted subject carries the standard provenance headers
/// (`// GENERATED STUB` + `// behavior_id:`) so `--adopt` (bug #840) and
/// the staleness re-render (bug #683) keep working unchanged.
library;

import 'dart:io';

import '../models/behavior.dart';
import 'platform_harness_context.dart';

/// Writes the platform-channel subject stub file for a platform behavior.
class PlatformHarnessSubjectWriter {
  const PlatformHarnessSubjectWriter({required this.context});

  /// The resolved scenario + path context (channel name lives inside the
  /// scenario — the committed intent).
  final PlatformHarnessContext context;

  /// Write the subject file at [subjectPath] for the behavior.
  Future<void> write({
    required Behavior behavior,
    required String subjectPath,
  }) async {
    final file = File(subjectPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(render(behavior));
  }

  /// Render the subject content the CURRENT binary would write for the
  /// behavior, without touching disk (staleness check contract, bug
  /// #683).
  String render(Behavior b) {
    final target = b.target.isEmpty ? 'subject_test' : b.target;
    final escapedChannel = _escapeSingleQuoted(context.scenario.channel);
    return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: ${b.kind.name}
// description: ${b.description}
//
// PLATFORM-CHANNEL SUBJECT (issue #831).
//
// This behavior's subject sits on the platform channel below. The paired
// harness test installs the certified fake (committed scenario at
// ${context.scenarioRef}) and asserts on the OBSERVED calls — arguments
// recorded, ordering preserved. Implement the stub by invoking the
// channel; the fake replays the scenario and records every call:
//
//   Future<Object?> $target() =>
//       kSubjectChannel.invokeMethod('<scripted method>', <arguments>);
//
// The stub throws [UnimplementedError] until wired — the paired harness
// fails through an assertion (honest red), never an uncaught error.
library;

import 'package:flutter/services.dart';

/// The platform channel this behavior drives (from the committed
/// scenario `${context.scenarioRef}` — intent, not an invention).
const MethodChannel kSubjectChannel = MethodChannel('$escapedChannel');

/// Harness inputs for behavior ${b.id}. Throws [UnimplementedError] until
/// implemented — honest red by design.
///
/// Target: invoke the channel method the scenario scripts, returning the
/// platform's answer. The certified fake records the call (method +
/// arguments) so the harness can assert on what was asked.
Future<Object?> $target() => throw UnimplementedError(
    '$target not implemented — invoke kSubjectChannel '
    '(${b.id} subject, issue #831)');
''';
  }

  String _escapeSingleQuoted(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}
