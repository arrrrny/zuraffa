// Issue #1125 ([A+ UPGRADE] tdd: add --explain flag — last gap to A+).
//
// Red-first contract:
//   * `--explain` is registered on the four highest-traffic `zfa tdd`
//     verbs — plan, run, verify, status (order 1). `converge` does not
//     exist in this plugin (no subcommand, no alias, no history), so the
//     fourth slot is `status`, the journal-convergence verdict CI gates
//     on;
//   * every verb emits the human-readable multi-line block under
//     `--explain`, carrying the ordered sections: features touched, the
//     lane (engine vs skin) run, the receipts written, the fix hints
//     emitted, and the one-paragraph narrative summary (order 2);
//   * `--explain` + `--json` together produce JSON + a separator + the
//     human-readable explanation, in that order (acceptance);
//   * `--json` alone is byte-identical to the pre-#1125 behavior: the
//     envelope stays the FINAL stdout line and no explanation prints
//     (constraint: --json semantics unchanged).
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/commands/plan_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/run_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/status_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/verify_command.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';

import 'helpers/spec_fixture.dart';
import 'helpers/tdd_fixture.dart';

/// The feature name the fixtures use.
const String kFeature = '090-tdd-fixture';

/// The five sections issue #1125 orders onto the explain block.
const String kFeaturesSection = 'features touched:';
const String kLaneSection = 'lane run:';
const String kReceiptsSection = 'receipts written:';
const String kFixHintsSection = 'fix hints:';
const String kSummarySection = 'summary:';

/// The block's separator header (doubles as the `--json` separator).
const String kExplainSeparatorPrefix = '--- explain:';

void _expectExplainSections(String out) {
  expect(out, contains(kFeaturesSection), reason: out);
  expect(out, contains(kLaneSection), reason: out);
  expect(out, contains(kReceiptsSection), reason: out);
  expect(out, contains(kFixHintsSection), reason: out);
  expect(out, contains(kSummarySection), reason: out);
  expect(out, contains(kExplainSeparatorPrefix), reason: out);
}

/// The last JSON object line of [out] (the zuraffa.verdict.v1 envelope
/// when `--json` is set — the canonical schema from the #1105 sweep).
Map<String, Object?>? _tryDecodeEnvelope(String out) {
  for (final line in out.trimRight().split('\n').reversed) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('{')) continue;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, Object?> &&
          decoded['schema'] == 'zuraffa.verdict.v1') {
        return decoded;
      }
    } on FormatException {
      continue;
    }
  }
  return null;
}

int _indexOf(String out, Pattern needle) {
  final text = out;
  final match = text.indexOf(needle);
  return match;
}

void main() {
  // The plugin is required to construct every command; one instance is
  // reused to avoid duplicate `addCommand` errors (json_flag_test
  // convention).
  final plugin = TddPlugin();

  group('U1 — --explain flag registration (order 1)', () {
    void expectExplainFlag(Command<void> command, String name) {
      final flag = command.argParser.options['explain'];
      expect(
        flag,
        isNotNull,
        reason: '$name: --explain flag must be registered',
      );
      expect(
        flag!.defaultsTo,
        isFalse,
        reason: '$name: --explain must default to false',
      );
      expect(flag.isFlag, isTrue, reason: '$name: --explain must be a flag');
    }

    test('plan has --explain', () {
      expectExplainFlag(PlanCommand(plugin), 'plan');
    });
    test('run has --explain', () {
      expectExplainFlag(RunCommand(plugin), 'run');
    });
    test('verify has --explain', () {
      expectExplainFlag(VerifyCommand(plugin), 'verify');
    });
    test('status has --explain', () {
      expectExplainFlag(StatusCommand(plugin), 'status');
    });
  });

  group('U2 — plan --explain', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('explain_plan_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      exitCode = 0;
    });

    test(
      'success path emits the full block with the written artifacts',
      () async {
        final featureDir = makeFeatureDir(tmp.path, kFeature);
        await writeSpec(featureDir, kMinimalAcceptance);

        final out = await CliRunner(exitOnCompletion: false).runCapturing([
          'tdd',
          'plan',
          kFeature,
          '--explain',
          '--project',
          tmp.path,
        ]);

        expect(exitCode, 0, reason: out);
        _expectExplainSections(out);
        // The touched feature and the lane truth (plan drives no lane).
        expect(out, contains('features touched: $kFeature'), reason: out);
        expect(out, contains(kLaneSection), reason: out);
        // The narrative names the artifact the plan wrote.
        expect(out, contains('tdd/test-list.md'), reason: out);
        expect(out, contains('summary:'), reason: out);
      },
    );

    test('coverage-gate refusal emits the block with the fix hint', () async {
      // A malformed FR bullet (no leading dash — the bug #846 shape)
      // produces no behavior row: the coverage gate refuses with a fix
      // instruction and NO artifacts.
      final featureDir = makeFeatureDir(tmp.path, kFeature);
      await writeSpec(featureDir, '''
# Spec: $kFeature

## Acceptance Scenarios

1. **Given** a fresh calculator **When** the user asks **Then** returns 42

## Functional Requirements

- **FR-001**: The system MUST return 42 when invoked with no args
**FR-002:** The system MUST log every invocation
''');

      final out = await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'plan',
        kFeature,
        '--explain',
        '--project',
        tmp.path,
      ]);

      expect(exitCode, 2, reason: out);
      _expectExplainSections(out);
      expect(out, contains('fix hints:'), reason: out);
      expect(out, isNot(contains('fix hints: none')), reason: out);
      // No artifacts were written — the receipts section says none.
      expect(out, contains('receipts written: none'), reason: out);
    });
  });

  group('U3 — run --explain (two-cycle meta driver)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(featureName: kFeature);
      await fx.writeFakeZfa();
      await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
      await File(fx.testListPath).writeAsString('''
# Test List: $kFeature

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | the first core behavior [core] | FR-001 | PENDING |
| W1 | the first skin behavior [skin] | FR-002 | PENDING |
''');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    Future<String> runMeta() =>
        CliRunner(exitOnCompletion: false).runCapturing([
          'tdd',
          'run',
          kFeature,
          '--explain',
          '--project',
          fx.root.path,
          '--zfa-bin',
          fx.fakeZfaBin,
        ]);

    test('green meta run names BOTH lanes and both receipts', () async {
      final out = await runMeta();

      expect(exitCode, 0, reason: out);
      _expectExplainSections(out);
      expect(out, contains('features touched: $kFeature'), reason: out);
      // The lane section names BOTH lanes on the green meta run.
      final laneMatch = RegExp(
        r'lane run: .*engine.*skin|lane run: .*skin.*engine',
      ).firstMatch(out);
      expect(laneMatch, isNotNull, reason: out);
      // Both lane receipts are named.
      expect(out, contains('tdd/04-engine-receipt.json'), reason: out);
      expect(out, contains('tdd/04-skin-receipt.json'), reason: out);
      expect(out, contains('result=complete'), reason: out);
    });

    test(
      'engine fail-fast names the engine lane and the honest stop',
      () async {
        await fx.setStepOutcome('make', 'U1', 'not-certified-red');

        final out = await runMeta();

        expect(exitCode, isNot(0), reason: out);
        _expectExplainSections(out);
        // The run stopped in the ENGINE lane — no skin step was spawned.
        expect(out, contains('lane run: engine'), reason: out);
        expect(out, isNot(contains('lane run: engine + skin')), reason: out);
        expect(out, contains('tdd/04-engine-receipt.json'), reason: out);
        expect(out, contains('result=stopped'), reason: out);
        expect(out, contains('stopped_at=U1:make'), reason: out);
      },
    );
  }, tags: ['slow']);

  group('U4 — verify --explain', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('explain_verify_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      exitCode = 0;
    });

    test(
      'NOT_ASSESSED path emits the block naming verification.md and the fix',
      () async {
        final featureDir = Directory(
          p.join(tmp.path, 'specs', '044-test-tdd-generation'),
        );
        await Directory(p.join(featureDir.path, 'tdd')).create(recursive: true);

        final out = await CliRunner(exitOnCompletion: false).runCapturing([
          'tdd',
          'verify',
          '--project',
          tmp.path,
          '--feature',
          '044-test-tdd-generation',
          '--explain',
        ]);

        expect(exitCode, isNot(0), reason: out);
        _expectExplainSections(out);
        expect(
          out,
          contains('features touched: 044-test-tdd-generation'),
          reason: out,
        );
        // The audit drives no lane — the lane section says so.
        expect(out, contains(kLaneSection), reason: out);
        // The written report is named.
        expect(out, contains('tdd/verification.md'), reason: out);
        expect(out, contains('gate=not_assessed'), reason: out);
        expect(out, isNot(contains('fix hints: none')), reason: out);
      },
    );
  });

  group('U5 — status --explain', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(featureName: kFeature);
      await fx.writeFakeZfa();
      await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
      await File(fx.testListPath).writeAsString('''
# Test List: $kFeature

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | the first core behavior [core] | FR-001 | PENDING |
| W1 | the first skin behavior [skin] | FR-002 | PENDING |
''');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test(
      'green journal explains both lane verdicts and the receipts',
      () async {
        final driver = CliRunner(exitOnCompletion: false);
        final engineOut = await driver.runCapturing([
          'tdd',
          'run-engine',
          kFeature,
          '--project',
          fx.root.path,
          '--zfa-bin',
          fx.fakeZfaBin,
        ]);
        expect(exitCode, 0, reason: engineOut);
        exitCode = 0;
        final skinOut = await driver.runCapturing([
          'tdd',
          'run-skin',
          kFeature,
          '--project',
          fx.root.path,
          '--zfa-bin',
          fx.fakeZfaBin,
        ]);
        expect(exitCode, 0, reason: skinOut);
        exitCode = 0;

        final out = await driver.runCapturing([
          'tdd',
          'status',
          kFeature,
          '--explain',
          '--project',
          fx.root.path,
        ]);

        expect(exitCode, 0, reason: out);
        _expectExplainSections(out);
        expect(out, contains('features touched: $kFeature'), reason: out);
        // The lane section carries BOTH lane verdicts.
        expect(out, contains('engine=green'), reason: out);
        expect(out, contains('skin=green'), reason: out);
        // The receipts the journal records are named.
        expect(out, contains('tdd/04-engine-receipt.json'), reason: out);
        expect(out, contains('tdd/04-skin-receipt.json'), reason: out);
      },
    );
  }, tags: ['slow']);

  group('U6 — --explain + --json together (acceptance)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('explain_json_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      exitCode = 0;
    });

    test('JSON verdict line, then separator, then the explanation', () async {
      final featureDir = makeFeatureDir(tmp.path, kFeature);
      await writeSpec(featureDir, kMinimalAcceptance);

      final out = await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'plan',
        kFeature,
        '--explain',
        '--json',
        '--project',
        tmp.path,
      ]);

      expect(exitCode, 0, reason: out);
      final envelope = _tryDecodeEnvelope(out);
      expect(envelope, isNotNull, reason: out);
      expect(envelope!['command'], 'plan', reason: out);
      // The ORDER: JSON first, separator, then the explanation.
      final jsonIndex = _indexOf(out, '"schema":"zuraffa.verdict.v1"');
      final separatorIndex = _indexOf(out, kExplainSeparatorPrefix);
      final summaryIndex = _indexOf(out, kSummarySection);
      expect(jsonIndex, greaterThanOrEqualTo(0), reason: out);
      expect(
        separatorIndex,
        greaterThan(jsonIndex),
        reason: 'the separator must follow the JSON line: $out',
      );
      expect(summaryIndex, greaterThan(separatorIndex), reason: out);
      _expectExplainSections(out);
    });
  });

  group('U7 — --json alone is unchanged (constraint)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('explain_json_only_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      exitCode = 0;
    });

    test(
      'the envelope stays the FINAL stdout line; no explanation prints',
      () async {
        final featureDir = makeFeatureDir(tmp.path, kFeature);
        await writeSpec(featureDir, kMinimalAcceptance);

        final out = await CliRunner(exitOnCompletion: false).runCapturing([
          'tdd',
          'plan',
          kFeature,
          '--json',
          '--project',
          tmp.path,
        ]);

        expect(exitCode, 0, reason: out);
        final lastNonEmpty = out.trimRight().split('\n').last;
        final decoded = jsonDecode(lastNonEmpty);
        expect(decoded, isA<Map<String, Object?>>(), reason: out);
        expect(
          (decoded as Map<String, Object?>)['schema'],
          'zuraffa.verdict.v1',
          reason: out,
        );
        // No explain block anywhere.
        expect(out, isNot(contains(kExplainSeparatorPrefix)), reason: out);
        expect(out, isNot(contains(kSummarySection)), reason: out);
      },
    );
  });
}
