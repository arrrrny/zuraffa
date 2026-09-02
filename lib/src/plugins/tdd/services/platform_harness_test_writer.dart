/// PlatformHarnessTestWriter — emits the Flutter test for a
/// `platform`-kind behavior (issue #831 — platform-channel test harness:
/// certified fakes for camera, barcode, permissions, notifications,
/// location).
///
/// The emitted file is the THREE-PROOF harness, all driven through the
/// certified fake written by `zfa tdd fake`:
///
///   0. Honest red — the paired subject stub throws
///      `UnimplementedError`; the harness captures it into an assertion
///      failure (house assertion-first pattern). Once the subject is
///      implemented, this proof measures the REAL channel interaction:
///      the fake replays the scenario and the subject's answer flows
///      through.
///   1. Certified replay — the fake replays the committed scenario's
///      scripted response (or error) for its first scripted method:
///      what the channel says is INTENT (the scenario file), never
///      improvised by the fake.
///   2. Observed calls — the fake records every call (method +
///      arguments) in invocation order; the harness asserts arguments
///      are recorded and ordering preserved (the issue's hard
///      requirement).
///   3. Unscripted methods fail loudly — the scenario's REQUIRED default
///      response fires for methods the intent never scripted (a silent
///      plausible null would be grading your own homework).
///
/// The same scenario runs on every platform the scenario declares in its
/// hosted matrix (`platforms`): the fake is platform-agnostic Dart, so
/// the proof file is identical across ios/android/macos hosted runs
/// (issue #831 requirement 5, "where feasible" — hosted execution stays
/// a TddProfile concern).
///
/// The emitted test carries the standard provenance headers
/// (`// GENERATED TEST` + `// behavior_id:`) so `--adopt` (bug #840) and
/// the staleness re-render (bug #683) keep working unchanged.
///
/// Target-project prerequisites (documented in the emitted header):
/// Flutter + the flutter test profile (`TddProfile.flutter`), and the
/// certified fake at the generated `fakes/<slug>_fake.dart` path
/// (generated together with the committed scenario by
/// `zfa tdd fake <channel> --behavior <id>`).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';
import 'platform_harness_context.dart';

/// Writes the platform-harness test file for a platform behavior.
class PlatformHarnessTestWriter {
  const PlatformHarnessTestWriter({required this.context});

  /// The resolved scenario + path context.
  final PlatformHarnessContext context;

  /// Write the harness test file at [testPath] importing the subject at
  /// [subjectPath]. The [golden] flag is accepted for shape parity with
  /// [BehaviorTestWriter.write]; platform-harness tests do not emit
  /// golden blocks (goldens measure pixels, not channel contracts).
  Future<void> write({
    required Behavior behavior,
    required String testPath,
    required String subjectPath,
    bool golden = false,
  }) async {
    final testFile = File(testPath);
    await testFile.parent.create(recursive: true);
    final relativeSubjectPath = p.relative(
      subjectPath,
      from: p.dirname(testPath),
    );
    final content = _renderTest(behavior, relativeSubjectPath);
    await testFile.writeAsString(content);
  }

  String _renderTest(Behavior b, String relativeSubjectPath) {
    final description = b.description;
    final escapedDescription = description.replaceAll("'", "\\'");
    final escapedGroup = '${b.id} (${b.sourceCriterion})'.replaceAll(
      "'",
      "\\'",
    );
    final target = b.target.isEmpty ? 'subject_test' : b.target;
    final fakeClass = context.fakeClassName;
    final fakeImport = context.fakeImport;
    final scenarioRef = context.scenarioRef;

    // The certified-replay proof target: the first scripted VALUE
    // method, or — when the scenario scripts only errors — the first
    // scripted ERROR method.
    final replayValue = context.replayValue;
    final replayError = context.replayError;
    final String replayProof;
    if (replayValue != null) {
      final expected = _dartLiteral(replayValue.value);
      replayProof =
          '''
    // What the channel says is INTENT: the scenario scripts the answer,
    // the fake replays it verbatim — the harness only checks equality.
    final replayed = await certifiedFake.channel
        .invokeMethod<Object?>('${_escapeSingleQuoted(replayValue.method)}');
    expect(replayed, $expected,
        reason: 'the certified fake must replay the committed scenario '
            'value verbatim (issue #831)');''';
    } else if (replayError != null) {
      replayProof =
          '''
    // What the channel says is INTENT: the scenario scripts the error,
    // the fake replays it verbatim — the harness only checks the class
    // and code.
    await expectLater(
      certifiedFake.channel
          .invokeMethod<Object?>('${_escapeSingleQuoted(replayError.method)}'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          '${_escapeSingleQuoted(replayError.code)}',
        ),
      ),
      reason: 'the certified fake must replay the committed scenario '
          'error verbatim (issue #831)',
    );''';
    } else {
      // Schema guarantees a default; an empty responses map still gives
      // the default as the replay target.
      replayProof = '''
    // The scenario scripts no per-method responses; the required default
    // IS the certified contract.
    await expectLater(
      certifiedFake.channel.invokeMethod<Object?>('available'),
      throwsA(isA<PlatformException>()),
      reason: 'the certified fake must replay the committed scenario '
          'default verbatim (issue #831)',
    );''';
    }

    // The loud-default proof depends on what the committed default is:
    // an error (the starter) throws; a value default replays.
    final String loudProof;
    if (context.scenario.defaultResponse.isError) {
      loudProof =
          '''
    await expectLater(
      certifiedFake.channel.invokeMethod<Object?>('__unscripted__'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          '${_escapeSingleQuoted(context.scenario.defaultResponse.errorCode!)}',
        ),
      ),
      reason: 'an unscripted method must fail LOUDLY with the committed '
          'default — a silent plausible null would be grading your own '
          'homework (issue #831)',
    );''';
    } else {
      loudProof =
          '''
    final replayed = await certifiedFake.channel
        .invokeMethod<Object?>('__unscripted__');
    expect(replayed, ${_dartLiteral(context.scenario.defaultResponse.value)},
        reason: 'the committed default response must replay verbatim '
            '(issue #831)');''';
    }

    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: ${b.kind.name}
// harness: platform-channel (issue #831 — certified fakes via committed scenario)
// description: $description
//
// PLATFORM HARNESS — three executable proofs in this one file:
//
//   1. Certified replay — the fake (registered via
//      TestDefaultBinaryMessengerBinding) replays the committed scenario
//      script from `$scenarioRef` verbatim: what the channel says is
//      intent, never improvised.
//   2. Observed calls — the fake records every call (method, arguments)
//      in invocation order; this file asserts arguments are recorded and
//      ordering preserved.
//   3. Unscripted methods fail loudly — the scenario's required default
//      response fires for methods the intent never scripted.
//
// The FIRST proof is the honest red on the subject stub (assertion-first
// capture); the replay/observed/loud proofs certify the HARNESS itself
// and stay green once the scenario + fake exist.
//
// The same scenario runs on every platform the scenario declares in its
// hosted matrix (issue #831 requirement 5): this file is platform-
// agnostic Dart; hosted execution (ios/android/macos) stays a TddProfile
// concern.
//
// PREREQUISITES (target project): Flutter + the flutter test profile;
// the certified fake at `$fakeImport` and the committed scenario at
// `$scenarioRef` (generate both with `zfa tdd fake <channel> --behavior
// ${b.id} --feature <feature>`). The paired subject at
// `$relativeSubjectPath` implements the channel interaction.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '$fakeImport' as fake;
import '$relativeSubjectPath' as subject;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$escapedGroup', () {
    late fake.$fakeClass certifiedFake;

    setUp(() {
      certifiedFake = fake.$fakeClass(scenarioPath: '$scenarioRef');
      certifiedFake.install();
    });

    tearDown(() {
      certifiedFake.uninstall();
    });

    // ----------------------------------------------------------------
    // Proof 1 — honest red on the subject stub (assertion-first).
    // ----------------------------------------------------------------
    testWidgets('${b.id} — $escapedDescription (subject drives the channel)',
        (tester) async {
      Object? result;
      try {
        result = await subject.$target();
      } on UnimplementedError catch (error) {
        result = error;
      }
      expect(
        result,
        isNull,
        reason:
            'the platform-channel subject must be implemented before this '
            'proof can observe it: implement $target by invoking '
            'kSubjectChannel (the stub throws UnimplementedError by '
            'design — honest red, issue #831)',
      );
    });

    // ----------------------------------------------------------------
    // Proof 2 — certified replay: the fake replays the scenario.
    // ----------------------------------------------------------------
    testWidgets('${b.id} — certified replay of the scripted response',
        (tester) async {
$replayProof
    });

    // ----------------------------------------------------------------
    // Proof 3 — observed calls: arguments recorded, ordering preserved.
    // ----------------------------------------------------------------
    testWidgets('${b.id} — observed calls recorded with arguments and order',
        (tester) async {
      await certifiedFake.channel
          .invokeMethod<Object?>('${_replayMethod()}', const {'step': 1});
      await certifiedFake.channel
          .invokeMethod<Object?>('${_replayMethod()}', const {'step': 2});

      expect(
        certifiedFake.recordedCalls,
        hasLength(2),
        reason: 'the fake must record every observed call (issue #831)',
      );
      expect(
        certifiedFake.recordedCalls[0].method,
        '${_replayMethod()}',
      );
      expect(
        certifiedFake.recordedCalls[0].arguments,
        const {'step': 1},
        reason: 'arguments must be recorded, not discarded',
      );
      expect(
        certifiedFake.recordedCalls[1].arguments,
        const {'step': 2},
        reason: 'ordering must be preserved: second call second',
      );
    });

    // ----------------------------------------------------------------
    // Proof 4 — unscripted methods fail loudly (certified honesty).
    // ----------------------------------------------------------------
    testWidgets('${b.id} — unscripted method fails loudly', (tester) async {
$loudProof
    });
  });
}
''';
  }

  /// The method the observed-calls proof drives twice: the first
  /// scripted method (value preferred, then error), or 'available' —
  /// the starter's scripted method — when the scenario scripts nothing
  /// per-method (the default still answers, so the proof measures
  /// recording, not the answer).
  String _replayMethod() {
    final replayValue = context.replayValue;
    if (replayValue != null) return replayValue.method;
    final replayError = context.replayError;
    if (replayError != null) return replayError.method;
    return 'available';
  }

  /// Render a JSON-decoded scenario value as an executable Dart literal
  /// for the emitted `expect`. Handles the JSON value domain: null, bool,
  /// num, String, List, Map.
  String _dartLiteral(Object? value) {
    if (value == null) return 'isNull';
    if (value is bool) return value ? 'isTrue' : 'isFalse';
    if (value is num || value is String) return jsonLiteral(value);
    if (value is List) {
      return 'const [${value.map(jsonLiteral).join(', ')}]';
    }
    if (value is Map) {
      return 'const {${value.entries.map((e) => '${jsonLiteral(e.key)}: ${jsonLiteral(e.value)}').join(', ')}}';
    }
    return jsonLiteral(value.toString());
  }

  String jsonLiteral(Object? value) {
    if (value == null) return 'null';
    if (value is num) return value.toString();
    if (value is bool) return value.toString();
    if (value is String) return "'${_escapeSingleQuoted(value)}'";
    if (value is List) {
      return '[${value.map(jsonLiteral).join(', ')}]';
    }
    if (value is Map) {
      return '{${value.entries.map((e) => '${jsonLiteral(e.key)}: ${jsonLiteral(e.value)}').join(', ')}}';
    }
    return "'${_escapeSingleQuoted(value.toString())}'";
  }

  String _escapeSingleQuoted(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}
