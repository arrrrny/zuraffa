// Issue #1140 (TDD-138) — the finder-kind column in the plan's behavior
// table, and gen's declared-kind contract.
//
// Issue #964 shipped the taxonomy inside the widget lane: the writer
// derives verb-matched assertions and verify-red refuses kind mismatches.
// Issue #1140 wires the taxonomy into the CONTRACT the loop shares:
//
//   1. `zfa tdd plan` outputs a "kind" column in the widget behavior
//      table — the scenario verbs' predicted assertion classes
//      (presence / absence / route-outcome / enabled-state / sequence,
//      `none` when no finder is derivable);
//   2. `zfa tdd gen` consumes the declared kind — the emitted pair
//      selects the assertion template by it, and a row whose kind column
//      drifted from its scenario prose (hand edit after plan) is refused
//      instead of silently generating stale assertions;
//   3. the reader accepts the 5-data-column kind shape while every
//      legacy 4-column list keeps parsing (back-compat pin);
//   4. verify-red's kind gate (#959/#964) certifies a red generated
//      through the declared-kind chain end to end.
//
// RED contract: every test here is CLI-observable (plan's emitted file,
// gen's exit code + artifacts, verify-red's verdict) so the suite runs
// — and fails — against the UNFIXED tree for honest red evidence. The
// reader-level kind-cell pins that need the new row field live in
// bug_1140_reader_kind_cell_test.dart and land with the fix.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/widget_scaffold.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  // ------------------------------------------------------------------
  // 1. plan — the widget behavior table carries the kind column
  // ------------------------------------------------------------------
  group('zfa tdd plan: the finder-kind column (issue #1140 wire-in 1)', () {
    late Directory tmpDir;
    late String featureDir;
    const featureName = '004-login-ui';

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug1140_plan_');
      featureDir = p.join(tmpDir.path, 'specs', featureName);
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    Future<String> runPlan() async {
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'plan',
        featureName,
        '--project',
        tmpDir.path,
      ]);
      return File(
        p.join(featureDir, 'tdd', 'test-list.md'),
      ).readAsString();
    }

    test('every scenario verb class lands in the kind column', () async {
      Directory(featureDir).createSync(recursive: true);
      await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: $featureName

## Acceptance Scenarios

1. **Given** the login view **When** it is opened **Then** shows the 'Sign in' title and hides the 'Invalid credentials' banner on initial render
   **Type**: widget
2. **Given** valid credentials **When** the user submits **Then** the app navigates to the route 'deal_list'
   **Type**: widget
3. **Given** a slow network **When** sign-in is in flight **Then** shows 'Signing in' and disables the 'Sign in' button
   **Type**: widget
4. **Given** a rendered form **When** the user reviews it **Then** the 'Sign in' button is disabled
   **Type**: widget
5. **Given** the login view **When** it is opened **Then** renders the brand theme
   **Type**: widget

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args
''');
      final list = await runPlan();

      // The widget table gains the kind column between behavior and
      // traces; the acceptance/unit tables keep the canonical 4-column
      // shape (finder kinds are a widget-lane concept).
      expect(list, contains('| id | behavior | kind | traces | state |'));
      expect(list, contains('| -- | -------- | ---- | ------ | ----- |'));
      expect(list, contains('| id | behavior | traces | state |'));

      // AC-1: presence AND absence in one scenario (the issue's
      // 004-login-ui AC-3 shape: shows the title, hides the banner).
      expect(
        list,
        contains(
          "| A1 | shows the 'Sign in' title and hides the 'Invalid "
          "credentials' banner on initial render | presence, absence "
          '| AC-1 | PENDING |',
        ),
      );
      // AC-2: navigation is a route outcome, never text presence.
      expect(
        list,
        contains(
          "| A2 | the app navigates to the route 'deal_list' "
          '| route-outcome | AC-2 | PENDING |',
        ),
      );
      // AC-3: an in-flight sequence carrying presence + enabled-state
      // sub-assertions — the sequence marker keeps gen's scaffold honest.
      expect(
        list,
        contains(
          "| A3 | while sign-in is in flight, shows 'Signing in' and "
          "disables the 'Sign in' button | presence, enabled-state, "
          'sequence | AC-3 | PENDING |',
        ),
      );
      // AC-4: post-copula enabled-state ("the button is disabled").
      expect(
        list,
        contains(
          "| A4 | the 'Sign in' button is disabled | enabled-state "
          '| AC-4 | PENDING |',
        ),
      );
      // A scenario with no derivable finder is explicit `none`, not an
      // empty cell a reader could silently mis-parse.
      expect(
        list,
        contains('| A5 | renders the brand theme | none | AC-5 | PENDING |'),
      );
      // The column is documented where the loop's humans read it.
      expect(list, contains('issue #1140'));
    });

    test('re-planning re-derives the column from the current prose '
        '(no accumulation)', () async {
      Directory(featureDir).createSync(recursive: true);
      await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: $featureName

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits **Then** the app navigates to the route 'deal_list'
   **Type**: widget

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args
''');
      final first = await runPlan();
      expect(
        first,
        contains(
          "| A1 | the app navigates to the route 'deal_list' "
          '| route-outcome | AC-1 | PENDING |',
        ),
      );
      final second = await runPlan();
      expect(
        second,
        contains(
          "| A1 | the app navigates to the route 'deal_list' "
          '| route-outcome | AC-1 | PENDING |',
        ),
        reason: 'the kind cell is re-derived, never duplicated',
      );
      expect(second, isNot(contains('route-outcome, route-outcome')));
    });
  });

  // ------------------------------------------------------------------
  // 2. gen — the declared kind selects the assertion template
  // ------------------------------------------------------------------
  group('zfa tdd gen: kind-driven templates (issue #1140 wire-in 2)', () {
    late Directory tmpDir;
    late String featureDir;
    const featureName = '1140-kind-column';

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug1140_gen_');
      featureDir = p.join(tmpDir.path, 'specs', featureName);
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      exitCode = 0;
    });

    Future<void> seedList(String widgetRows) async {
      Directory(p.join(featureDir, 'tdd')).createSync(recursive: true);
      await File(p.join(featureDir, 'spec.md')).writeAsString(
        '**Template Version**: `zuraffa-1.0`\n\n'
        '- **AC-1**: renders the dashboard shell on mount\n',
      );
      await File(p.join(featureDir, 'tdd', 'test-list.md')).writeAsString('''
# Test List: $featureName

## Outer loop: widget behaviors

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |
$widgetRows

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | returns 42 when invoked with no args | FR-001 | PENDING |
''');
    }

    List<String> genArgs(String id) => [
      'tdd',
      'gen',
      '--project',
      tmpDir.path,
      '--feature',
      featureName,
      id,
      '--widget-shell',
      'materialapp',
    ];

    String testFileOf(String id) =>
        p.join(tmpDir.path, 'test', 'tdd', featureName, '${id.toLowerCase()}_test.dart');

    test('a route-outcome row generates the pushed-routes assertion, '
        'never find.text of the route name', () async {
      await seedList(
        "| A2 | the app navigates to the route 'deal_list' "
        '| route-outcome | AC-2 | PENDING |',
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('A2'));
      expect(exitCode, 0, reason: 'out: $out');
      final content = await File(testFileOf('a2')).readAsString();
      expect(content, contains("expect(observer.pushedNames, contains('deal_list'),"));
      expect(
        content,
        isNot(contains("find.text('deal_list')")),
        reason: "the certified lie: asserting a route as on-screen text",
      );
    });

    test('an absence row generates findsNothing', () async {
      await seedList(
        "| A3 | the error banner hides 'An error occurred' after a retry "
        '| absence | AC-3 | PENDING |',
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('A3'));
      expect(exitCode, 0, reason: 'out: $out');
      final content = await File(testFileOf('a3')).readAsString();
      expect(
        content,
        contains("expect(find.text('An error occurred'), findsNothing);"),
      );
    });

    test('a `none` row stays an honest scaffolded placeholder', () async {
      await seedList('| A5 | renders the brand theme | none | AC-5 | PENDING |');
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('A5'));
      expect(exitCode, 0, reason: 'out: $out');
      final content = await File(testFileOf('a5')).readAsString();
      expect(content, contains(scaffoldedMarker));
    });

    test('a drifted kind column is REFUSED — declared route-outcome, '
        'prose now presence (hand edit after plan)', () async {
      await seedList(
        "| A2 | shows the 'deal_list' page after sign-in "
        '| route-outcome | AC-2 | PENDING |',
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('A2'));
      expect(exitCode, isNot(0), reason: 'out: $out');
      expect(out, contains('finder kind'));
      expect(out, contains('route-outcome'));
      expect(out, contains('presence'));
      expect(
        out,
        contains('Refusing to write any file'),
        reason: 'fail fast before any artifact, FR-002',
      );
      expect(
        File(testFileOf('a2')).existsSync(),
        isFalse,
        reason: 'zero artifacts on refusal',
      );
    });

    test('a drifted kind column is REFUSED in the reverse direction — '
        'declared presence, prose now navigates', () async {
      await seedList(
        "| A2 | the app navigates to the route 'deal_list' "
        '| presence | AC-2 | PENDING |',
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('A2'));
      expect(exitCode, isNot(0), reason: 'out: $out');
      expect(out, contains('route-outcome'));
      expect(out, contains('presence'));
      expect(File(testFileOf('a2')).existsSync(), isFalse);
    });

    test('an unknown kind token is a malformed cell naming the token', () async {
      await seedList(
        "| A2 | the app navigates to the route 'deal_list' "
        '| bogus | AC-2 | PENDING |',
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('A2'));
      expect(exitCode, isNot(0), reason: 'out: $out');
      expect(out, contains('bogus'));
    });

    test('legacy 4-column rows keep generating (back-compat pin)', () async {
      Directory(p.join(featureDir, 'tdd')).createSync(recursive: true);
      await File(p.join(featureDir, 'spec.md')).writeAsString(
        '**Template Version**: `zuraffa-1.0`\n\n'
        '- **AC-1**: renders the dashboard shell on mount\n',
      );
      await File(p.join(featureDir, 'tdd', 'test-list.md')).writeAsString('''
## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | returns 42 when invoked with no args | FR-001 | PENDING |
''');
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('U1'));
      expect(exitCode, 0, reason: 'out: $out');
      expect(
        File(
          p.join(tmpDir.path, 'test', 'tdd', featureName, 'u1_test.dart'),
        ).existsSync(),
        isTrue,
      );
    });
  });

  // ------------------------------------------------------------------
  // 3. verify-red — the declared-kind chain certifies end to end
  // ------------------------------------------------------------------
  group('verify-red composes with the declared kind (issue #1140)', () {
    late TddFixture fx;
    const featureName = '1140-kind-column';

    /// A failing single-test transcript with an assertion signature —
    /// the honest red the kind gate certifies.
    const failingTranscript = '''
00:00 +0 -1: test/tdd/1140-kind-column/a2_test.dart: A2 nav [E]
00:00 -1: Expected: contains 'deal_list'
  Actual: Which: <[]>

Some tests failed.
''';

    setUp(() async {
      fx = await TddFixture.create(featureName: featureName);
      final spy = await fx.writeSpyScript(
        'single',
        output: failingTranscript,
        exit: '1',
      );
      await fx.rewriteProfile(singleTemplate: spy, suiteTemplate: spy);
      final tddDir = Directory(p.join(fx.featureDir, 'tdd'));
      await tddDir.create(recursive: true);
      await File(p.join(tddDir.path, 'test-list.md')).writeAsString('''
## Outer loop: widget behaviors

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |
| A2 | the app navigates to the route 'deal_list' | route-outcome | AC-2 | PENDING |
''');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('plan kind → gen template → certified red', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final genOut = await runner.runCapturing([
        'tdd',
        'gen',
        '--project',
        fx.root.path,
        '--feature',
        featureName,
        'A2',
        '--widget-shell',
        'materialapp',
      ]);
      expect(exitCode, 0, reason: 'gen out: $genOut');
      final testFile = File(
        p.join(fx.root.path, 'test', 'tdd', featureName, 'a2_test.dart'),
      );
      expect(await testFile.existsSync(), isTrue);
      final content = await testFile.readAsString();
      expect(content, contains('pushedNames'));

      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--project',
        fx.root.path,
        'A2',
      ]);
      expect(
        out,
        contains('classification=assertion certified=true'),
        reason: 'out: $out',
      );
      expect(exitCode, 0);
    });
  });
}
