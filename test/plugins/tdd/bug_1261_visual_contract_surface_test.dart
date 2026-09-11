// Bug #1261 — tdd: no visual-contract surface — goldens are a gen-only
// flag, adaptive_slots never proposed, SKIN lanes fall through to a path
// that cannot express skins.
//
// RED contract (issue #1261), one group per remediation axis:
//
//   1. SPEC GRAMMAR — a `## Lanes` SKIN row declares the golden gate per
//      behavior (`golden: true` / `golden: [W1, W2]`), parsed into
//      LaneDeclaration.goldenIds by SpecParser.parseLanes.
//   2. PLAN/SPLIT SURFACE — plan marks golden SKIN widget rows with the
//      ` [golden]` tag in 04-SKIN.md, renders a `## Visual contract`
//      section, lists the gate in the meta-index golden column, and
//      split carries the same marks + records golden_ids in the receipt.
//   3. GEN PICKS THE GATE UP WITHOUT THE FLAG — a golden-declared widget
//      row generates the matchesGoldenFile hook with NO --golden flag,
//      stays idempotent on re-gen (the staleness mirror renders the
//      same bytes), and a declared golden on a non-widget row warns and
//      stays inert.
//   4. NO VISUAL CONTRACT WARNING — plan proposes adaptive_slots for a
//      SKIN lane with widget behaviors and none declared, and warns
//      "this skin has no visual contract" when the lane has neither
//      slots nor goldens; declarations of goldens silence the warning.
//   5. SCAFFOLD HONESTY — the generated widget scaffold's header comment
//      mentions golden baselines ONLY when a golden hook was actually
//      emitted (never when gen ran without a golden gate).
//
// All assertions are CONTENT-level (no Flutter test execution): the
// generated pair is validated by its emitted source, mirroring the
// bug #830 test conventions.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  // ------------------------------------------------------------------
  // 1. SpecParser.parseLanes — the `golden:` declaration
  // ------------------------------------------------------------------
  group('bug1261 spec parser: golden declaration in ## Lanes', () {
    test('golden: true marks every behavior of the lane golden', () {
      final lanes = const SpecParser().parseLanes('''
## Lanes

```yaml
Lanes:
  - lane: SKIN
    behaviors: [W1, W2, A1]
    flutter_allowed: true
    golden: true
```
''');
      expect(lanes, hasLength(1));
      expect(lanes.single.goldenIds, ['W1', 'W2', 'A1']);
    });

    test('golden: true resolves even when declared BEFORE behaviors', () {
      final lanes = const SpecParser().parseLanes('''
## Lanes

```yaml
Lanes:
  - lane: SKIN
    golden: true
    behaviors: [W1, W2]
    flutter_allowed: true
```
''');
      expect(lanes.single.goldenIds, ['W1', 'W2']);
    });

    test('a golden id list marks the subset, not the whole lane', () {
      final lanes = const SpecParser().parseLanes('''
## Lanes

```yaml
Lanes:
  - lane: SKIN
    behaviors: [W1, W2, W3]
    flutter_allowed: true
    golden: [W1, W3]
```
''');
      expect(lanes.single.goldenIds, ['W1', 'W3']);
    });

    test('golden: false and an absent golden key mark nothing', () {
      final lanes = const SpecParser().parseLanes('''
## Lanes

```yaml
Lanes:
  - lane: SKIN
    behaviors: [W1]
    flutter_allowed: true
    golden: false
  - lane: CORE
    behaviors: [U1]
    flutter_allowed: false
```
''');
      expect(lanes[0].goldenIds, isEmpty);
      expect(lanes[1].goldenIds, isEmpty);
    });
  });

  // ------------------------------------------------------------------
  // 2. TestListReader — the ` [golden]` row tag
  // ------------------------------------------------------------------
  group('bug1261 reader: the [golden] row tag', () {
    test('a golden-tagged row parses golden and strips the tag', () async {
      final dir = Directory.systemTemp.createTempSync('bug1261_reader_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'tdd')).createSync(recursive: true);
      await File(p.join(dir.path, 'tdd', 'test-list.md')).writeAsString('''
## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| W1 | renders the gradient sign-in button [golden] | AC-1 | PENDING |
| W2 | renders the error shake | AC-2 | PENDING |
''');
      final rows = await TestListReader(dir.path).read();
      final w1 = rows.where((r) => r.id == 'W1').single;
      final w2 = rows.where((r) => r.id == 'W2').single;
      expect(w1.golden, isTrue, reason: 'the tag marks the row golden');
      expect(
        w1.description,
        'renders the gradient sign-in button',
        reason: 'the tag never leaks into the generated assertion prose',
      );
      expect(w2.golden, isFalse);
    });

    test('the tag normalizes whitespace runs around it (mutation kill: '
        'the extract whitespace-collapse regex)', () async {
      final dir = Directory.systemTemp.createTempSync('bug1261_reader_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'tdd')).createSync(recursive: true);
      await File(p.join(dir.path, 'tdd', 'test-list.md')).writeAsString('''
## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| W1 | renders the gradient sign-in button   [golden] | AC-1 | PENDING |
''');
      final rows = await TestListReader(dir.path).read();
      expect(rows.single.golden, isTrue);
      expect(
        rows.single.description,
        'renders the gradient sign-in button',
        reason: 'the whitespace run the tag left behind is collapsed',
      );
    });

    test('a lane plan with a ## Visual contract section reads cleanly — '
        'the section is a declaration, its rows are not behaviors '
        '(mutation kill: the declarative-skip disjunction)', () async {
      final dir = Directory.systemTemp.createTempSync('bug1261_reader_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'tdd')).createSync(recursive: true);
      await File(p.join(dir.path, 'tdd', 'test-list.md')).writeAsString('''
# Skin Plan: 080-login-skin (SKIN + BOTH)

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| W1 | renders the gradient sign-in button [golden] | AC-1 | PENDING |

## Visual contract

Golden-gated skin behaviors (bug #1261).

| behavior | golden gate |
| -------- | ----------- |
| W1 | matchesGoldenFile |
''');
      // Without the visual-contract skip, the section's `| W1 |
      // matchesGoldenFile |` row mis-parses as a malformed behavior row
      // and read() throws.
      final rows = await TestListReader(dir.path).read();
      expect(rows, hasLength(1));
      expect(rows.single.id, 'W1');
      expect(rows.single.golden, isTrue);
    });
  });

  // ------------------------------------------------------------------
  // 3. plan — the visual-contract surface in 04-SKIN.md
  // ------------------------------------------------------------------
  group('bug1261 plan: golden marks + visual contract section', () {
    late Directory tmpDir;
    const feature = '080-login-skin';
    final skinPlan = File(p.join('specs', feature, 'tdd', '04-SKIN.md'));

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug1261_plan_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    Future<void> seedSpec(String lanesExtra) async {
      final specDir = Directory(p.join(tmpDir.path, 'specs', feature));
      await specDir.create(recursive: true);
      await File(p.join(specDir.path, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: login skin

## Acceptance Scenarios

1. **Given** the login page, **When** it opens, **Then** the gradient sign-in button is rendered on the login page.

## Functional Requirements

- **FR-001**: the login skin renders the gradient sign-in button.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [A1]
    flutter_allowed: true
$lanesExtra
```
''');
    }

    test('a golden-declared SKIN lane marks widget rows golden in '
        '04-SKIN.md and lists the gate in the meta-index', () async {
      await seedSpec('    golden: true');
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'plan',
        feature,
        '--project',
        tmpDir.path,
      ]);
      expect(CliRunner.lastDispatchedExitCode, 0);
      final skin = await File(
        p.join(tmpDir.path, skinPlan.path),
      ).readAsString();
      // The row tag: the machine-readable gate gen reads.
      final a1Row = skin
          .split('\n')
          .firstWhere(
            (line) => line.startsWith('| A1 |') && line.contains('gradient'),
          );
      expect(
        a1Row,
        contains('[golden]'),
        reason: 'the golden gate rides the row as a [golden] tag',
      );
      // The row keeps the canonical 4-column pipe structure the shared
      // reader parses (mutation kill: the tableLine cell pipes).
      expect(
        a1Row,
        matches(RegExp(r'^\| A1 \| .+ \[golden\] \| .+ \| PENDING \|$')),
      );
      // The visual-contract section: the plan surface the bug says is
      // missing (it follows the behavior tables as the contract
      // summary — the section lists the golden-gated behaviors).
      expect(skin, contains('## Visual contract'));
      final section = skin.indexOf('## Visual contract');
      final sectionBody = skin.substring(section);
      expect(
        sectionBody,
        contains('| A1 |'),
        reason: 'the visual contract names the golden-gated behavior',
      );
      // The section table shape (mutation kill: the gate-table strings).
      expect(sectionBody, contains('| behavior | golden gate |'));
      expect(sectionBody, contains('| A1 | matchesGoldenFile |'));
      // The meta-index golden column.
      final meta = await File(
        p.join(tmpDir.path, 'specs', feature, 'tdd', 'test-list.md'),
      ).readAsString();
      // The lane-table header with the golden column (mutation kill: the
      // meta-index header strings).
      expect(
        meta,
        contains('| lane | behaviors | flutter allowed | golden | plan |'),
      );
      expect(meta, contains('golden'));
      expect(meta, contains('A1'));
    });

    test(
      'a SKIN lane without goldens writes no visual contract section',
      () async {
        await seedSpec('');
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing([
          'tdd',
          'plan',
          feature,
          '--project',
          tmpDir.path,
        ]);
        expect(CliRunner.lastDispatchedExitCode, 0);
        final skin = await File(
          p.join(tmpDir.path, skinPlan.path),
        ).readAsString();
        expect(skin, isNot(contains('[golden]')));
        expect(skin, isNot(contains('## Visual contract')));
      },
    );

    test('a golden declaration rides the HAND row (the W id the lane '
        'reserves) and only the declared rows — mutation kill: the '
        'hand-row golden gate conjunction', () async {
      // W1 is a hand id: declared in ## Lanes, derived from no scenario.
      // golden: [W1] marks W1; the derived widget row A1 and the
      // undeclared hand row W2 stay unmarked.
      await seedSpec('    golden: [W1]');
      // Declare W1 and W2 as hand rows of the SKIN lane.
      final specFile = File(p.join(tmpDir.path, 'specs', feature, 'spec.md'));
      final spec = await specFile.readAsString();
      await specFile.writeAsString(
        spec.replaceFirst('behaviors: [A1]', 'behaviors: [A1, W1, W2]'),
      );
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'plan',
        feature,
        '--project',
        tmpDir.path,
      ]);
      expect(CliRunner.lastDispatchedExitCode, 0);
      final skin = await File(
        p.join(tmpDir.path, skinPlan.path),
      ).readAsString();
      final w1Row = skin
          .split('\n')
          .firstWhere(
            (line) => line.startsWith('| W1 |') && line.contains('LANE:'),
          );
      expect(
        w1Row,
        contains('[golden]'),
        reason: 'the declared hand row is golden-gated',
      );
      final w2Row = skin
          .split('\n')
          .firstWhere(
            (line) => line.startsWith('| W2 |') && line.contains('LANE:'),
          );
      expect(
        w2Row,
        isNot(contains('[golden]')),
        reason:
            'a SKIN hand row the golden declaration does not name '
            'stays unmarked',
      );
      final a1Row = skin
          .split('\n')
          .firstWhere(
            (line) => line.startsWith('| A1 |') && line.contains('gradient'),
          );
      expect(
        a1Row,
        isNot(contains('[golden]')),
        reason:
            'a SKIN hand row is not marked golden by side effect — '
            'only the declared ids are',
      );
    });
  });

  // ------------------------------------------------------------------
  // 4. plan — no-visual-contract warning + adaptive_slots proposal
  // ------------------------------------------------------------------
  group('bug1261 plan: the no-visual-contract warning', () {
    late Directory tmpDir;
    const feature = '080-login-skin';

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug1261_warn_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    Future<String> plan({required String lanesExtra}) async {
      final specDir = Directory(p.join(tmpDir.path, 'specs', feature));
      await specDir.create(recursive: true);
      await File(p.join(specDir.path, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: login skin

## Acceptance Scenarios

1. **Given** the login page, **When** it opens, **Then** the gradient sign-in button is rendered on the login page.

## Functional Requirements

- **FR-001**: the login skin renders the gradient sign-in button.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [A1]
    flutter_allowed: true
$lanesExtra
```
''');
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'plan',
        feature,
        '--project',
        tmpDir.path,
      ]);
      expect(CliRunner.lastDispatchedExitCode, 0);
      return out;
    }

    test('a widget SKIN lane with neither slots nor goldens warns no '
        'visual contract and proposes adaptive_slots', () async {
      final out = await plan(lanesExtra: '');
      expect(out, contains('no visual contract'));
      expect(out, contains('adaptive_slots'));
      expect(
        out,
        contains(
          'proposing adaptive_slots: [mobile, ios, '
          'android, macos]',
        ),
      );
    });

    test('declared goldens silence the warning (the skin HAS a visual '
        'contract), the proposal still fires without slots', () async {
      final out = await plan(lanesExtra: '    golden: true');
      expect(out, isNot(contains('no visual contract')));
      expect(out, contains('proposing adaptive_slots'));
    });

    test('declared slots silence both the warning and the proposal', () async {
      final out = await plan(lanesExtra: '    adaptive_slots: [mobile, ios]');
      expect(out, isNot(contains('no visual contract')));
      expect(out, isNot(contains('proposing adaptive_slots')));
    });
  });

  // ------------------------------------------------------------------
  // 5. plan — golden declaration drift refuses
  // ------------------------------------------------------------------
  group('bug1261 plan: golden declaration drift refuses', () {
    late Directory tmpDir;
    const feature = '080-login-skin';

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug1261_drift_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    Future<String> planWithLanes(String lanesBody) async {
      final specDir = Directory(p.join(tmpDir.path, 'specs', feature));
      await specDir.create(recursive: true);
      await File(p.join(specDir.path, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: login skin

## Acceptance Scenarios

1. **Given** the login page, **When** it opens, **Then** the gradient sign-in button is rendered on the login page.

## Functional Requirements

- **FR-001**: the login skin renders the gradient sign-in button.
  traces: Contract

## Lanes

```yaml
Lanes:
$lanesBody
```
''');
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'plan',
        feature,
        '--project',
        tmpDir.path,
      ]);
      return out;
    }

    test('a golden id outside the lane behaviors refuses', () async {
      final out = await planWithLanes('''
  - lane: CORE
    behaviors: [U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [A1]
    flutter_allowed: true
    golden: [W9]
''');
      expect(CliRunner.lastDispatchedExitCode, 2);
      expect(out, contains('golden'));
      expect(out, contains('W9'));
      expect(
        Directory(p.join(tmpDir.path, 'specs', feature, 'tdd')).existsSync(),
        isFalse,
        reason: 'a refused plan writes no artifacts',
      );
    });

    test('golden on a non-SKIN lane refuses', () async {
      final out = await planWithLanes('''
  - lane: CORE
    behaviors: [U1]
    flutter_allowed: false
    golden: true
  - lane: SKIN
    behaviors: [A1]
    flutter_allowed: true
''');
      expect(CliRunner.lastDispatchedExitCode, 2);
      expect(out, contains('SKIN'));
    });

    test('golden on a non-widget SKIN behavior refuses', () async {
      final out = await planWithLanes('''
  - lane: SKIN
    behaviors: [U1]
    flutter_allowed: true
    golden: true
''');
      expect(CliRunner.lastDispatchedExitCode, 2);
      expect(out, contains('widget-only'));
    });
  });

  // ------------------------------------------------------------------
  // 6. split — the migrated plan carries the golden surface
  // ------------------------------------------------------------------
  group('bug1261 split: golden marks + receipt', () {
    late Directory tmpDir;
    const feature = '080-login-skin';

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug1261_split_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test('split marks golden rows in 04-SKIN.md and records golden_ids '
        'in the receipt', () async {
      final specDir = Directory(p.join(tmpDir.path, 'specs', feature));
      await Directory(p.join(specDir.path, 'tdd')).create(recursive: true);
      await File(p.join(specDir.path, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: login skin

## Lanes

```yaml
Lanes:
  - lane: SKIN
    behaviors: [W1, W2]
    flutter_allowed: true
    golden: [W1]
```
''');
      await File(p.join(specDir.path, 'tdd', 'test-list.md')).writeAsString('''
## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| W1 | renders the gradient sign-in button | AC-1 | PENDING |
| W2 | renders the error shake | AC-2 | PENDING |
''');
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'split',
        feature,
        '--project',
        tmpDir.path,
      ]);
      expect(CliRunner.lastDispatchedExitCode, 0);
      final skin = await File(
        p.join(specDir.path, 'tdd', '04-SKIN.md'),
      ).readAsString();
      final w1Row = skin
          .split('\n')
          .firstWhere(
            (line) => line.startsWith('| W1 |') && line.contains('gradient'),
          );
      final w2Row = skin
          .split('\n')
          .firstWhere(
            (line) => line.startsWith('| W2 |') && line.contains('shake'),
          );
      expect(w1Row, contains('[golden]'));
      expect(w2Row, isNot(contains('[golden]')));
      expect(skin, contains('## Visual contract'));
      final receipt = await File(
        p.join(specDir.path, 'tdd', 'split-receipt.json'),
      ).readAsString();
      expect(receipt, contains('golden_ids'));
      expect(receipt, contains('W1'));
    });
  });

  // ------------------------------------------------------------------
  // 7. gen — the declared golden gate, without the flag
  // ------------------------------------------------------------------
  group('bug1261 gen: spec-declared golden without the flag', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug1261_gen_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    List<String> genArgs(String id, [List<String> extra = const <String>[]]) =>
        ['tdd', 'gen', '--project', tmpDir.path, id, ...extra];

    /// Seeds a feature whose plan ALREADY ran: the test list is the lane
    /// meta-index and 04-SKIN.md carries the golden mark on W1.
    Future<void> seedPlannedFeature() async {
      final specDir = Directory(p.join(tmpDir.path, 'specs', '080-login-skin'));
      await Directory(p.join(specDir.path, 'tdd')).create(recursive: true);
      await File(
        p.join(specDir.path, 'spec.md'),
      ).writeAsString('**Template Version**: `zuraffa-1.0`\n');
      await File(p.join(specDir.path, 'tdd', 'test-list.md')).writeAsString('''
# Test List: 080-login-skin (meta-index)

## Lane split

| lane | behaviors | flutter allowed | plan |
| ---- | --------- | --------------- | ---- |
| SKIN | W1, W2 | true | `04-SKIN.md` |

- engine plan: `04-ENGINE.md`
- skin plan: `04-SKIN.md`
- engine/skin contract: `04-CONTRACT.md`
''');
      await File(
        p.join(specDir.path, 'tdd', '04-ENGINE.md'),
      ).writeAsString('# Engine Plan: 080-login-skin (CORE + BOTH)\n');
      await File(p.join(specDir.path, 'tdd', '04-SKIN.md')).writeAsString('''
# Skin Plan: 080-login-skin (SKIN + BOTH)

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| W1 | renders the gradient sign-in button [golden] | AC-1 | PENDING |
| W2 | renders the error shake | AC-2 | PENDING |
''');
    }

    String testPath(String id) => p.join(
      tmpDir.path,
      'test',
      'tdd',
      '080-login-skin',
      '${id.toLowerCase().replaceAll('-', '_')}_test.dart',
    );

    test('a golden-marked widget row generates the matchesGoldenFile hook '
        'without --golden', () async {
      await seedPlannedFeature();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('W1'));
      expect(out, contains('behavior_id: W1'));
      expect(
        out,
        isNot(contains('the declaration is inert')),
        reason:
            'no spurious inert-golden warning for a widget-kind row '
            '(mutation kill: the warning-gate disjunction)',
      );
      final testContent = await File(testPath('w1')).readAsString();
      expect(testContent, contains('matchesGoldenFile('));
      expect(testContent, contains('goldens/'));
      // The scaffold header MAY mention goldens here: the hook exists.
      expect(testContent, contains('golden baselines are committed'));
    });

    test('an unmarked widget row generates NO golden hook and NO golden '
        'comment (the scaffold never promises a harness that does not '
        'exist)', () async {
      await seedPlannedFeature();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('W2'));
      expect(out, contains('behavior_id: W2'));
      final testContent = await File(testPath('w2')).readAsString();
      expect(testContent, contains('testWidgets('));
      expect(testContent, isNot(contains('matchesGoldenFile')));
      expect(testContent, isNot(contains('golden baselines are committed')));
      expect(testContent, isNot(contains('test/tdd/goldens/')));
    });

    test('re-gen of a golden-marked row stays idempotent (the staleness '
        'mirror renders the same golden bytes)', () async {
      await seedPlannedFeature();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('W1'));
      final before = await File(testPath('w1')).readAsString();
      final out = await runner.runCapturing(genArgs('W1'));
      final after = await File(testPath('w1')).readAsString();
      expect(
        after,
        before,
        reason: 'the staleness check must not strip the golden hook',
      );
      expect(
        out.toLowerCase(),
        isNot(contains('regenerated')),
        reason: 'no false staleness: the pair matches the current render',
      );
      expect(after, contains('matchesGoldenFile('));
    });

    test(
      'a declared golden on a non-widget row warns and stays inert',
      () async {
        final specDir = Directory(
          p.join(tmpDir.path, 'specs', '080-login-skin'),
        );
        await Directory(p.join(specDir.path, 'tdd')).create(recursive: true);
        await File(p.join(specDir.path, 'tdd', 'test-list.md')).writeAsString(
          '''
## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | persists the session [golden] | FR-001 | PENDING |
''',
        );
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(genArgs('U1'));
        expect(
          CliRunner.lastDispatchedExitCode,
          0,
          reason: 'a warning, never a refusal',
        );
        expect(out, contains('widget-only'));
        final testContent = await File(
          p.join(tmpDir.path, 'test', 'tdd', '080-login-skin', 'u1_test.dart'),
        ).readAsString();
        expect(testContent, isNot(contains('matchesGoldenFile')));
      },
    );
  });

  // ------------------------------------------------------------------
  // 8. gen --golden (the flag) — the scaffold comment contract
  // ------------------------------------------------------------------
  group('bug1261 gen: --golden flag keeps working, comment stays honest', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug1261_flag_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    Future<void> seedTestList() async {
      final specDir = Directory(
        p.join(tmpDir.path, 'specs', '044-test-tdd-generation'),
      );
      await Directory(p.join(specDir.path, 'tdd')).create(recursive: true);
      await File(
        p.join(specDir.path, 'spec.md'),
      ).writeAsString('**Template Version**: `zuraffa-1.0`\n');
      await File(p.join(specDir.path, 'tdd', 'test-list.md')).writeAsString('''
## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| B-003 | renders the brand theme on the dashboard | AC-1 | PENDING |
''');
    }

    test('gen --golden emits the hook AND the golden comment', () async {
      await seedTestList();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'gen',
        '--project',
        tmpDir.path,
        'B-003',
        '--golden',
      ]);
      final testContent = await File(
        p.join(
          tmpDir.path,
          'test',
          'tdd',
          '044-test-tdd-generation',
          'b_003_test.dart',
        ),
      ).readAsString();
      expect(testContent, contains('matchesGoldenFile('));
      expect(testContent, contains('golden baselines are committed'));
    });
  });
}
