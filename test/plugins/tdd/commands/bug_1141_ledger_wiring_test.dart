/// Tests for the UI surface ledger wiring (issue #1141, U1+U2 — plan
/// writes the ledger artifact).
///
/// #965 shipped `UiLedgerBuilder` + `I18nKeyTable.toDeclaredSurfaces` as
/// library functions with NO command producing the ledger — 075's
/// outstanding T002. This spec wires the derivation into `zfa tdd plan`:
/// one row per declared surface (text/route/affordance from the scenario
/// literals and Presentation component tokens, `t.<key>` key rows whose
/// provers are the behaviors quoting the anchor), written to
/// `specs/<feature>/tdd/ui-ledger.md` + the `ui-ledger.json` twin.
///
/// RED phase: plan knows nothing about the ledger — the artifact
/// assertions fail.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/i18n_key_contract.dart';
import 'package:zuraffa/src/plugins/tdd/services/ui_ledger_projection.dart';
import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';

const String feature = '1141-ledger-fixture';

/// A zuraffa-1.0 spec whose behaviors quote literals and whose
/// Presentation contract declares a keyed surface (the same contract
/// shape `zfa tdd plan` parses via SpecParser.parseLayerContracts).
const String keyedSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the login view **When** the user opens it **Then** the login view shows 'Sign in'
2. **Given** the app boots **When** the session resumes **Then** the app navigates to 'deal_list'

## Functional Requirements

- **FR-001**: The system shall show 'Welcome back' above the credential form.
  traces: AuthRepository
- **FR-002**: The system shall disable 'Continue' until the form is valid.
  traces: AuthRepository

## Layer Contracts

**Presentation**:
- `LoginSection`: `ShadInput` for email, `key: auth.signIn -> 'Sign in'`

**Domain**:
- `AuthRepository`: `signIn`
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug_1141_ledger_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  Future<void> seedSpec(String spec) async {
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
  }

  Future<String> runPlan() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'plan',
      // Issue #1480: this suite's subject is the UI-surface LEDGER, not
      // the routing gate — the zero-surface variant plans the legacy
      // fallback shape on purpose.
      '--allow-unit-fallback',
      '--project',
      tmpDir.path,
      feature,
    ]);
  }

  File ledgerMd() => File(p.join(tddDir, 'ui-ledger.md'));
  File ledgerJson() => File(p.join(tddDir, 'ui-ledger.json'));

  group('bug 1141 U1: plan writes the UI surface ledger', () {
    test('the keyed anchor feeds a t.<key> row (never a text row), '
        'prover traced at the declaration level', () async {
      await seedSpec(keyedSpec);
      final out = await runPlan();

      expect(exitCode, 0, reason: 'plan succeeded: $out');
      expect(ledgerMd().existsSync(), isTrue, reason: 'the ledger artifact');
      final md = await ledgerMd().readAsString();
      // A1 quotes 'Sign in' — the anchor of auth.signIn — so the key row
      // appears and NO text row carries 'Sign in'. Planned provers are
      // NOT-DONE at plan time (state recomputes on read — the 0965 model:
      // the proven-by column carries GREEN provers only).
      expect(md, contains('| t.auth.signIn | key |  | NOT-DONE |'));
      expect(md, isNot(contains('| Sign in | text |')));
      // The prover TRACING lives in the declaration: the projection
      // derives A1 as t.auth.signIn's prover (unit-level, below).
    });

    test('the projection traces the quoting behavior as the declared '
        'prover of its surface (and anchors feed key rows only)', () {
      final keys = I18nKeyTable.of([
        const I18nKeyContract(key: 'auth.signIn', anchor: 'Sign in'),
      ]);
      final declared = UiLedgerProjection.derive(
        behaviors: [
          const LedgerBehaviorInput(
            id: 'A1',
            description: "the login view shows 'Sign in'",
          ),
          const LedgerBehaviorInput(
            id: 'U1',
            description: "The system shall show 'Welcome back' above the form.",
          ),
        ],
        keys: keys,
      );
      final keyRow = declared.singleWhere((s) => s.surface == 't.auth.signIn');
      expect(keyRow.kind, UiSurfaceKind.key);
      expect(keyRow.declaredProvers, ['A1']);
      final textRow = declared.singleWhere((s) => s.surface == 'Welcome back');
      expect(textRow.kind, UiSurfaceKind.text);
      expect(textRow.declaredProvers, ['U1']);
      expect(
        declared.where((s) => s.surface == 'Sign in'),
        isEmpty,
        reason: 'the anchor feeds the key row, never a text row',
      );
    });

    test('possessive apostrophes do not become quoted ledger surfaces', () {
      final declared = UiLedgerProjection.derive(
        behaviors: const [
          LedgerBehaviorInput(
            id: 'U1',
            description: "the receipt's hash and the spec's mtime stay current",
          ),
        ],
        keys: I18nKeyTable.of(const []),
      );

      expect(declared, isEmpty);
    });

    test('unkeyed presence literals become text rows', () async {
      await seedSpec(keyedSpec);
      await runPlan();

      final md = await ledgerMd().readAsString();
      // FR-001 → U1 quotes 'Welcome back' — no key anchored to it.
      expect(md, contains('| Welcome back | text |  | NOT-DONE |'));
    });

    test('route and enabled-state literals become route/affordance rows '
        '(absence literals never do)', () async {
      await seedSpec(keyedSpec);
      await runPlan();

      final md = await ledgerMd().readAsString();
      // A2 navigates to 'deal_list' → route row; FR-002 disables
      // 'Continue' → affordance row.
      expect(md, contains('| deal_list | route |  | NOT-DONE |'));
      expect(md, contains('| Continue | affordance |  | NOT-DONE |'));
    });

    test('the JSON twin carries the same rows', () async {
      await seedSpec(keyedSpec);
      await runPlan();

      expect(ledgerJson().existsSync(), isTrue);
      final decoded = jsonDecode(await ledgerJson().readAsString());
      expect(decoded, isA<List<dynamic>>());
      final rows = decoded as List<dynamic>;
      final keyRow =
          rows.singleWhere(
                (r) =>
                    (r as Map<String, dynamic>)['surface'] == 't.auth.signIn',
              )
              as Map<String, dynamic>;
      expect(keyRow['kind'], 'key');
      expect(
        keyRow['provenBy'],
        isEmpty,
        reason: 'planned provers are NOT-DONE, never counted green',
      );
      expect(keyRow['state'], 'NOT-DONE');
    });

    test('the plan stdout reports the ledger write', () async {
      await seedSpec(keyedSpec);
      final out = await runPlan();

      expect(out, contains('ui-ledger.md'));
      expect(out, contains('key row'));
    });
  });

  group('bug 1141 U2: the empty ledger is a visible fact', () {
    test(
      'a zero-surface spec writes the empty ledger and still exits 0',
      () async {
        await seedSpec('''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the service **When** it is called **Then** the service responds

## Functional Requirements

- **FR-001**: The system shall respond to the call.
''');
        final out = await runPlan();

        expect(exitCode, 0, reason: 'plan succeeded: $out');
        expect(ledgerMd().existsSync(), isTrue);
        final md = await ledgerMd().readAsString();
        expect(md, contains('| surface | kind | proven by | state |'));
        expect(md, isNot(contains('| t.')));
      },
    );
  });
}
