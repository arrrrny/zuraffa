// Tests for bug #830 — widget-test subject kind: UI specs cannot be built
// by pure-function subjects.
//
// RED contract (issue #830): an acceptance behavior whose scenario prose
// carries UI intent ("renders the brand theme", "sidebar on macOS",
// "bottom nav on iOS") is currently planned and generated as a
// plain-function / scenario-runner pair whose green proves nothing about
// the UI (SC-001..SC-004 unmeasurable). These tests pin the widget
// subject-kind contract end to end:
//
//   1. TestListReader accepts widget-kind rows (section header + 6-column
//      kind cell);
//   2. SpecParser marks UI-intent acceptance scenarios as widget kind
//      (spec-driven plan marking);
//   3. plan renders a widget section in test-list.md;
//   4. gen emits a testWidgets pair — a view-builder subject stub and a
//      widget test that pumps it and asserts the acceptance scenario —
//      via `--kind widget`, spec-driven widget rows, and a `--golden`
//      baseline hook;
//   5. the red classifier routes widget pump exceptions to runner-error
//      and keeps assertion mismatches honest red.
//
// All assertions are CONTENT-level (no Flutter test execution): widget
// tests run on the flutter profile's slower tier (issue #830), so the
// generated pair is validated by its emitted source here.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/red_classification.dart';
import 'package:zuraffa/src/plugins/tdd/services/red_classifier.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  // ------------------------------------------------------------------
  // 1. TestListReader — widget kind rows
  // ------------------------------------------------------------------
  group('bug830 reader: widget kind rows', () {
    test('a widget section header marks its rows widget kind', () async {
      final dir = Directory.systemTemp.createTempSync('bug830_reader_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'tdd')).createSync(recursive: true);
      await File(p.join(dir.path, 'tdd', 'test-list.md')).writeAsString('''
## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | renders the brand theme | AC-1 | PENDING |
''');
      final rows = await TestListReader(dir.path).read();
      expect(rows, hasLength(1));
      expect(rows.single.id, 'A1');
      expect(rows.single.kind.name, 'widget');
    });

    test('a 6-column row with a widget kind cell reads as widget', () async {
      final dir = Directory.systemTemp.createTempSync('bug830_reader_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'tdd')).createSync(recursive: true);
      await File(p.join(dir.path, 'tdd', 'test-list.md')).writeAsString('''
## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | six column ui row | AC-1 | PENDING |

| A2 | renders the brand theme | AC-2 | widget | PENDING | |
''');
      final rows = await TestListReader(dir.path).read();
      final a2 = rows.where((r) => r.id == 'A2').single;
      expect(a2.kind.name, 'widget');
    });
  });

  // ------------------------------------------------------------------
  // 2. SpecParser — UI-intent acceptance scenarios -> widget kind
  // ------------------------------------------------------------------
  group('bug830 spec parser: UI acceptance prose is widget kind', () {
    test('a UI-intent acceptance scenario is marked widget', () {
      final behaviors = const SpecParser().parse('080-ui-dashboard', '''
# Spec: UI dashboard

## Acceptance Scenarios

1. **Given** the app shell, **When** the dashboard opens, **Then** the dashboard renders the brand theme.

## Functional Requirements

- **FR-001**: the dashboard exposes a pure view-model contract.
''');
      expect(behaviors, hasLength(2));
      // A-behavior: UI intent -> widget. U-behavior: untouched -> unit.
      expect(behaviors.first.id, 'A1');
      expect(behaviors.first.kind.name, 'widget');
      expect(behaviors.last.id, 'U1');
      expect(behaviors.last.kind.name, 'unit');
    });

    test('layout nouns (sidebar, bottom nav) are UI intent too', () {
      final behaviors = const SpecParser().parse('081-shell', '''
1. **Given** a macOS desktop, **When** the shell mounts, **Then** the sidebar is visible on macOS and the bottom nav bar is hidden.
''');
      expect(behaviors.single.kind.name, 'widget');
    });

    test('non-UI acceptance scenarios stay acceptance', () {
      final behaviors = const SpecParser().parse('002-toggle', '''
1. **Given** an entity with a boolean field, **When** running the generator, **Then** a toggle method is generated in the repository interface.
''');
      expect(behaviors.single.kind.name, 'acceptance');
    });
  });

  // ------------------------------------------------------------------
  // 3. plan — spec-driven widget marking in test-list.md
  // ------------------------------------------------------------------
  group('bug830 plan: widget section in test-list.md', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug830_plan_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test('plan marks UI acceptance scenarios widget in test-list.md', () async {
      final specDir = Directory(
        p.join(tmpDir.path, 'specs', '080-ui-dashboard'),
      );
      await specDir.create(recursive: true);
      await File(p.join(specDir.path, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: UI dashboard

## Acceptance Scenarios

1. **Given** the app shell, **When** the dashboard opens, **Then** the dashboard renders the brand theme.

## Functional Requirements

- **FR-001**: the dashboard exposes a pure view-model contract.
''');
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'plan',
        '080-ui-dashboard',
        '--project',
        tmpDir.path,
      ]);
      final list = await File(
        p.join(specDir.path, 'tdd', 'test-list.md'),
      ).readAsString();
      expect(list, contains('## Outer loop: widget behaviors'));
      // The UI scenario row lands in the widget section (after its header).
      final widgetHeader = list.indexOf('## Outer loop: widget behaviors');
      expect(list.indexOf('| A1 |'), greaterThan(widgetHeader));
      // The widget row carries the UI scenario prose under the widget
      // section (the count line goes to the real stdout, not the
      // capturing zone — the file is the contract here).
      expect(list.substring(widgetHeader), contains('renders the brand theme'));
    });

    test('non-UI acceptance rows stay in the acceptance section', () async {
      final specDir = Directory(p.join(tmpDir.path, 'specs', '002-toggle'));
      await specDir.create(recursive: true);
      await File(p.join(specDir.path, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: toggle

## Acceptance Scenarios

1. **Given** an entity with a boolean field, **When** running the generator, **Then** a toggle method is generated in the repository interface.

## Functional Requirements

- **FR-001**: the generator emits the toggle method.
''');
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'plan',
        '002-toggle',
        '--project',
        tmpDir.path,
      ]);
      final list = await File(
        p.join(specDir.path, 'tdd', 'test-list.md'),
      ).readAsString();
      // The acceptance row appears BEFORE the widget section header.
      final acceptanceRow = list.indexOf('| A1 |');
      final widgetHeader = list.indexOf('## Outer loop: widget behaviors');
      expect(acceptanceRow, greaterThanOrEqualTo(0));
      expect(acceptanceRow, lessThan(widgetHeader));
    });
  });

  // ------------------------------------------------------------------
  // 4. gen — widget pair emission
  // ------------------------------------------------------------------
  group('bug830 gen: widget pair (--kind widget)', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug830_gen_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    List<String> genArgs(String id, [List<String> extra = const <String>[]]) =>
        ['tdd', 'gen', '--project', tmpDir.path, id, ...extra];

    Future<void> seedSpecAndTestList({
      String behaviorId = 'B-003',
      String classification = 'acceptance',
      String description = 'renders the brand theme on the dashboard',
      String sourceCriterion = 'AC-1',
      String target = 'subject_b003',
    }) async {
      final specDir = Directory(
        p.join(tmpDir.path, 'specs', '044-test-tdd-generation'),
      );
      await specDir.create(recursive: true);
      await File(
        p.join(specDir.path, 'spec.md'),
      ).writeAsString('**Template Version**: `zuraffa-1.0`\n\n- **$sourceCriterion**: $description\n');
      await Directory(p.join(specDir.path, 'tdd')).create(recursive: true);
      await File(p.join(specDir.path, 'tdd', 'test-list.md')).writeAsString('''
| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| $behaviorId | $description | $sourceCriterion | $classification | PENDING | $target |
''');
    }

    test(
      'gen --kind widget emits a widget test + view-builder subject',
      () async {
        await seedSpecAndTestList();
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          genArgs('B-003', ['--kind', 'widget']),
        );
        expect(out, contains('behavior_id: B-003'));

        final testFile = File(
          p.join(
            tmpDir.path,
            'test',
            'tdd',
            '044-test-tdd-generation',
            'b_003_test.dart',
          ),
        );
        expect(testFile.existsSync(), isTrue);
        final testContent = await testFile.readAsString();
        // Widget test shape (issue #830 remediation 1+2):
        expect(testContent, contains('kind: widget'));
        expect(
          testContent,
          contains("import 'package:flutter_test/flutter_test.dart';"),
        );
        expect(testContent, contains('testWidgets('));
        expect(testContent, contains('pumpWidget('));
        // Honest red: the stub's UnimplementedError is captured BEFORE the
        // pump, so first-run red is assertion-shaped (never a pump escape).
        expect(testContent, contains('on UnimplementedError catch'));
        expect(testContent, contains('isNot(isA<UnimplementedError>())'));

        final subjectFile = File(
          p.join(
            tmpDir.path,
            'lib',
            'tdd',
            '044-test-tdd-generation',
            'b_003_subject.dart',
          ),
        );
        expect(subjectFile.existsSync(), isTrue);
        final subjectContent = await subjectFile.readAsString();
        // View-builder subject stub (issue #830 remediation 3):
        expect(subjectContent, contains('kind: widget'));
        expect(
          subjectContent,
          contains("import 'package:flutter/material.dart';"),
        );
        expect(subjectContent, contains('Widget subject_b003()'));
        expect(subjectContent, contains('UnimplementedError'));
      },
    );

    test(
      'a spec-driven widget row emits the widget pair without a flag',
      () async {
        await seedSpecAndTestList(classification: 'widget');
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(genArgs('B-003'));
        expect(out, contains('behavior_id: B-003'));
        final testContent = await File(
          p.join(
            tmpDir.path,
            'test',
            'tdd',
            '044-test-tdd-generation',
            'b_003_test.dart',
          ),
        ).readAsString();
        expect(testContent, contains('testWidgets('));
        final subjectContent = await File(
          p.join(
            tmpDir.path,
            'lib',
            'tdd',
            '044-test-tdd-generation',
            'b_003_subject.dart',
          ),
        ).readAsString();
        expect(subjectContent, contains('Widget subject_b003()'));
      },
    );

    test('gen --kind widget --golden emits the golden baseline hook', () async {
      await seedSpecAndTestList();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        genArgs('B-003', ['--kind', 'widget', '--golden']),
      );
      expect(out, contains('behavior_id: B-003'));
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
      expect(testContent, contains('goldens/'));
      expect(testContent, contains('--update-goldens'));
    });

    test('--golden without widget kind is rejected pre-write', () async {
      await seedSpecAndTestList(classification: 'unit');
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('B-003', ['--golden']));
      expect(out, contains('--golden'));
      final testDir = Directory(p.join(tmpDir.path, 'test'));
      final testFiles = testDir.existsSync()
          ? testDir.listSync(recursive: true)
          : <FileSystemEntity>[];
      expect(testFiles, isEmpty);
    });

    test('--kind with an unknown value is a usage error pre-write', () async {
      await seedSpecAndTestList();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        genArgs('B-003', ['--kind', 'widgety']),
      );
      expect(out, contains('kind'));
      final testDir = Directory(p.join(tmpDir.path, 'test'));
      final testFiles = testDir.existsSync()
          ? testDir.listSync(recursive: true)
          : <FileSystemEntity>[];
      expect(testFiles, isEmpty);
    });
  });

  // ------------------------------------------------------------------
  // 5. red classifier — widget failure taxonomy (issue #830 remediation 4)
  // ------------------------------------------------------------------
  group('bug830 classifier: widget failures', () {
    RunRecord record(String output) => RunRecord(
      command: 'flutter test test/tdd/a1_test.dart --plain-name "A1"',
      exitCode: 1,
      output: output,
      startedProcess: true,
      testCount: 1,
    );

    test('an assertion mismatch coexisting with exception text stays honest '
        'red (real flutter_test shape)', () {
      // REAL transcript shape (e2e-captured, Flutter 3.47.2): flutter_test
      // wraps EVERY test failure in the FLUTTER TEST FRAMEWORK banner and
      // rethrows it as "The following TestFailure was thrown running a
      // test" — an assertion mismatch that coexists with exception text
      // is STILL an assertion: the expect demonstrably fired. The
      // idealized pre-fix pin (crash outranks assertion) was corrected by
      // the e2e honest-red run of the generated widget pair.
      final r = record('''
00:00 +0: loading /e2e/test/tdd/a1_test.dart
00:00 +0: A1 (AC-1) A1 — the dashboard renders the brand theme.
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞══════════════════════
The following TestFailure was thrown running a test:
Expected: not <Instance of 'UnimplementedError'>
  Actual: UnimplementedError:<UnimplementedError: subject_a1 not implemented>

This was caught by the test expectation on the following line:
  test/tdd/a1_test.dart line 37
00:00 +0 -1: A1 (AC-1) A1 — the dashboard renders the brand theme. [E]
  Test failed. See exception logs above.
00:00 +0 -1: Some tests failed.
''');
      expect(classify(r).label, 'assertion');
    });

    test('an assertion-only widget failure stays honest red', () {
      final r = record('''
00:01 +0: loading test/tdd/a1_test.dart
00:01 +0 -1: A1 — renders the brand theme [E]
  Expected: exactly one matching node in the widget tree
    Actual: _TextWidgetFinder:<zero widgets with text "Brand">
   Which: none

00:01 +0 -1: Some tests failed.
''');
      expect(classify(r).label, 'assertion');
    });

    test('a build crash without an assertion signature is runner-error', () {
      // Issue #830: exception in pump/build = compile/runner tier. The
      // framework crash banner with NO assertion signature means the
      // behavior was never honestly observed.
      final r = record('''
00:01 +0: loading test/tdd/a1_test.dart
00:01 +0 -1: A1 — renders the brand theme [E]
══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═════════════════════════════
The following StateError was thrown building Dashboard(dirty):
  Bad state: no theme

00:01 +0 -1: Some tests failed.
''');
      expect(classify(r).label, 'runner-error');
    });

    test('a stub error escaping pump is runner-error', () {
      final r = record('''
00:01 +0: loading test/tdd/a1_test.dart
00:01 +0 -1: A1 — renders the brand theme [E]
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞══════════════════════
The following UnimplementedError was thrown running a test:
  UnimplementedError: subject_a1 not implemented

00:01 +0 -1: Some tests failed.
''');
      expect(classify(r).label, 'runner-error');
    });

    test('a pumpAndSettle timeout is runner-error', () {
      final r = record('''
00:01 +0: loading test/tdd/a1_test.dart
00:01 +0 -1: A1 — renders the brand theme [E]
  pumpAndSettle timed out

00:01 +0 -1: Some tests failed.
''');
      expect(classify(r).label, 'runner-error');
    });
  });
}
