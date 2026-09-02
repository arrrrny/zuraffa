/// `PlatformHarnessContext` — everything the platform-harness writers
/// need beyond the [Behavior] itself (issue #831).
///
/// Gen resolves the context ONCE per platform behavior (before the
/// ownership preflight, so a refusal happens before any file is
/// touched):
///
///   - the committed scenario (loaded + schema-validated), which names
///     the channel, the scripted responses, and the hosted matrix;
///   - the fake import path the emitted test uses (relative to the
///     test's directory: `fakes/<snake-id>_fake.dart`);
///   - the scenario reference the emitted test passes to the fake's
///     constructor (package-root relative, flutter test runs from the
///     package root).
library;

import '../models/channel_scenario.dart';

class PlatformHarnessContext {
  const PlatformHarnessContext({
    required this.scenario,
    required this.slug,
    required this.fakeImport,
    required this.scenarioRef,
  });

  /// The committed, schema-valid scenario for this behavior.
  final ChannelScenario scenario;

  /// The snake-case slug (the behavior id's snake case): names the fake
  /// class (`<Pascal>Fake`) and the scenario file.
  final String slug;

  /// The fake import the emitted test writes, relative to the test's
  /// own directory (`fakes/<slug>_fake.dart`).
  final String fakeImport;

  /// The scenario path passed to the fake's constructor (package-root
  /// relative — flutter test runs from the package root).
  final String scenarioRef;

  /// The fake class name the emitted test references (`fake.T1Fake`).
  String get fakeClassName {
    final pascal = slug
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join();
    return '${pascal}Fake';
  }

  /// The first scripted VALUE method (the certified-replay proof's happy
  /// path); null when the scenario scripts only errors — the harness
  /// then replays the first scripted ERROR method instead.
  ({String method, Object? value})? get replayValue {
    for (final entry in scenario.responses.entries) {
      if (!entry.value.isError) {
        return (method: entry.key, value: entry.value.value);
      }
    }
    return null;
  }

  /// The first scripted ERROR method (used for the certified replay
  /// when the scenario scripts no value responses).
  ({String method, String code})? get replayError {
    for (final entry in scenario.responses.entries) {
      if (entry.value.isError) {
        return (method: entry.key, code: entry.value.errorCode!);
      }
    }
    return null;
  }
}
