// Issue #1482 — the `zfa tdd run` routing-provenance preflight (fast
// tier, pure service). The driver tier (issue_1482_run_preflight_driver_test.dart)
// covers the command-level refusal and the --force bypass over a scripted
// fake zfa; this suite pins the SERVICE contract:
//
//   U-1482-1 — the preflight reads the plan-produced `## Routing
//              provenance` section (test-list.md, following the lane
//              meta-index into 04-ENGINE.md / 04-SKIN.md) plus the
//              TestListReader rows and returns a finding for a
//              fallback-routed UNIT row: id, description, criterion
//              tokens (FR-001 / FR-005).
//   U-1482-2 — the offending-row filter is EXACTLY: kind unit AND
//              provenance `[fallback: ...]` AND state not done AND (no
//              generated test OR contentIsVacuousGreen) — acceptance
//              fallback rows, declared unit rows, DONE fallback rows and
//              hand-completed fallback rows are never offending
//              (FR-001 / FR-006).
//   U-1482-3 — fail-open boundaries: no/unreadable test list → ok; no
//              provenance section → ok; a leftover lane plan beside a
//              legacy list → ignored; declared/off-criteria route lines
//              are not fallback; the gate needs only the plan artifacts
//              (no toolchain) — O(1) reads (FR-005 / SC-1).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/routing_provenance_preflight.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

/// The exact `route:` line shape `plan_command.dart` / `lane_split.dart`
/// render into the `## Routing provenance` section.
const _provenanceBody = '''
## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted
— a declared marker/contract row, or the labeled legacy fallback to
migrate.

route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane (func surface) [declared: contract row Formatter.format]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: A1 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: W1 -> widget lane [fallback: legacy description classifier matched — add `**Type**: widget` to the scenario]
route: U4 -> refused [danglingReference: behavior "U4" traces to "Nope", which names no declared contract row]
''';

Directory _tmpProject() {
  final root = Directory.systemTemp.createTempSync('zfa_1482_preflight_');
  File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync(
    'name: preflight_fixture\nenvironment:\n  sdk: ^3.11.0\n',
  );
  return root;
}

void _seedList(
  Directory root,
  String feature,
  String body, {
  String file = 'test-list.md',
}) {
  final dir = Directory(p.join(root.path, 'specs', feature, 'tdd'));
  dir.createSync(recursive: true);
  File(p.join(dir.path, file)).writeAsStringSync(body);
}

/// The 4-column test-list body `plan_command.dart` writes, with the
/// plan's routing provenance section appended.
String _list({String provenance = _provenanceBody}) =>
    '''
# Test List: 1482-preflight-fixture

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | renders the todo list header | FR-010 | PENDING |

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| W1 | renders the brand theme | FR-011 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | lets the user add a todo with a title | FR-001 | PENDING |
| U2 | formats the stored title | FR-002, Formatter.format | PENDING |
| U3 | already completed by a previous run | FR-003 | DONE |
| U4 | traces a dangling row name | Nope | PENDING |

$provenance
''';

void main() {
  late Directory root;

  setUp(() => root = _tmpProject());
  tearDown(() {
    root.deleteSync(recursive: true);
  });

  RoutingProvenancePreflight gate(String feature) => RoutingProvenancePreflight(
    projectRoot: root.path,
    featureDir: p.join(root.path, 'specs', feature),
  );

  test(
    'U-1482-1: a fallback-routed unit row is the finding — id, description, criterion token',
    () async {
      _seedList(root, '1482-preflight-fixture', _list());

      final report = await gate('1482-preflight-fixture').check();

      expect(report.ok, isFalse);
      // ONLY U1: U2 is declared, U3 is DONE, U4 refused, A1/W1 are not
      // unit rows — the gate invents nothing the provenance does not say.
      expect(report.offending, hasLength(1));
      final finding = report.offending.single;
      expect(finding.id, 'U1');
      expect(finding.description, 'lets the user add a todo with a title');
      expect(finding.criterionTraces, ['FR-001']);
      // The rendered row line is the spec's exact shape (FR-002).
      expect(
        finding.line,
        '  U1 — lets the user add a todo with a title '
        '(no declared contract trace, fallback to FR-001)',
      );
    },
  );

  test(
    'U-1482-1b: every offending row is listed at once, in list order',
    () async {
      _seedList(
        root,
        '1482-preflight-fixture',
        _list(
          provenance: '''
## Routing provenance

route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
''',
        ),
      );

      final report = await gate('1482-preflight-fixture').check();

      // U3 is DONE → not offending; U1 and U2 both listed, list order.
      expect(report.offending.map((f) => f.id).toList(), ['U1', 'U2']);
      expect(
        report.headerLine,
        'run: preflight failed — 2 unit behaviour(s) cannot pass make:',
      );
    },
  );

  test(
    'U-1482-1c: a row with no criterion token omits the fallback suffix',
    () async {
      _seedList(root, '1482-preflight-fixture', '''
# Test List: 1482-preflight-fixture

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | syncs when the network returns |  | PENDING |

## Routing provenance

route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
''');

      final report = await gate('1482-preflight-fixture').check();

      expect(
        report.offending.single.line,
        '  U1 — syncs when the network returns (no declared contract trace)',
      );
      expect(report.offending.single.criterionTraces, isEmpty);
    },
  );

  test(
    'U-1482-2a: acceptance and widget fallback rows are never offending',
    () async {
      _seedList(root, '1482-preflight-fixture', _list());

      final report = await gate('1482-preflight-fixture').check();

      // A1 and W1 are fallback-routed but NOT unit rows — the acceptance
      // prose lane is make's composition fallback BY DESIGN (FR-009) and
      // the widget lane needs no contract surface (issue #939).
      expect(report.offending.map((f) => f.id), ['U1']);
    },
  );

  test(
    'U-1482-2b: a fallback unit whose test is hand-completed (non-vacuous) is not offending',
    () async {
      _seedList(root, '1482-preflight-fixture', _list());
      // The #827 namespaced layout, the snake-cased id (U2 → u2 — declared
      // routing already; hand-complete U1 instead).
      final testPath = p.join(
        root.path,
        'test',
        'tdd',
        '1482-preflight-fixture',
        'u1_test.dart',
      );
      File(testPath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
// Hand-completed: a real assertion on the observable outcome.
import 'package:test/test.dart';

void main() {
  test('U1 — adds a todo', () {
    expect(subject.subjectU1('title').title, 'title');
  });
}
''');

      final report = await gate('1482-preflight-fixture').check();

      // Evidence beats state: the test carries a real assertion set, so
      // the row CAN pass make — not listed.
      expect(report.ok, isTrue, reason: report.offending.toString());
      expect(report.offending, isEmpty);
    },
  );

  test(
    'U-1482-2c: a fallback unit whose test is the bare guard (vacuous) IS offending',
    () async {
      _seedList(root, '1482-preflight-fixture', _list());
      final testPath = p.join(
        root.path,
        'test',
        'tdd',
        '1482-preflight-fixture',
        'u1_test.dart',
      );
      File(testPath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
// GENERATED TEST — the fallback path's guard-only shape (no marker).
import 'package:test/test.dart';

void main() {
  test('U1 — adds a todo', () {
    final result = (() {
      try {
        return subject.subjectU1('title');
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''');

      final report = await gate('1482-preflight-fixture').check();

      expect(report.offending.map((f) => f.id), ['U1']);
    },
  );

  test(
    'U-1482-2d: a DONE fallback row is not offending (evidence beats state)',
    () async {
      _seedList(
        root,
        '1482-preflight-fixture',
        _list(
          provenance: '''
## Routing provenance

route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
''',
        ),
      );

      final report = await gate('1482-preflight-fixture').check();

      // U3 is DONE: its loop is complete — refusing would block legitimate
      // resumption (evidence beats state, FR-003 of spec 1008).
      expect(report.ok, isTrue, reason: report.offending.toString());
    },
  );

  test(
    'U-1482-3a: no test list fails open (the driver names the real problem)',
    () async {
      final report = await gate('never-planned').check();

      expect(report.ok, isTrue);
      expect(report.offending, isEmpty);
    },
  );

  test(
    'U-1482-3b: no provenance section fails open (nothing is invented)',
    () async {
      _seedList(root, '1482-preflight-fixture', '''
# Test List: 1482-preflight-fixture

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | lets the user add a todo | FR-001 | PENDING |
''');

      final report = await gate('1482-preflight-fixture').check();

      expect(report.ok, isTrue);
      expect(report.offending, isEmpty);
    },
  );

  test(
    'U-1482-3c: lane meta-index lists resolve provenance from the lane plans',
    () async {
      // The spec 1008 lane split: test-list.md is a meta-index pointing at
      // 04-ENGINE.md / 04-SKIN.md; the provenance rides the lane files.
      _seedList(root, '1482-preflight-fixture', '''
# Test List: 1482-preflight-fixture

## Lane split

- engine plan: `04-ENGINE.md`
- skin plan: `04-SKIN.md`
- engine/skin contract: `04-CONTRACT.md`

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | lets the user add a todo | FR-001 | PENDING |
''', file: 'test-list.md');
      _seedList(root, '1482-preflight-fixture', '''
# Engine Plan

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | lets the user add a todo | FR-001 | PENDING |

## Routing provenance

route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
''', file: '04-ENGINE.md');
      // The skin plan always exists beside the engine plan (plan writes
      // both) — empty for this fixture: no skin rows.
      _seedList(
        root,
        '1482-preflight-fixture',
        '# Skin Plan\n',
        file: '04-SKIN.md',
      );

      final report = await gate('1482-preflight-fixture').check();

      expect(report.ok, isFalse);
      expect(report.offending.single.id, 'U1');
    },
  );

  test(
    'U-1482-3d: the report and the remedy constant compose the FR-002 refusal block',
    () async {
      _seedList(root, '1482-preflight-fixture', _list());

      final report = await gate('1482-preflight-fixture').check();
      final block = [
        report.headerLine,
        ...report.offending.map((f) => f.line),
        kRoutingPreflightSuggested,
      ].join('\n');

      // The three-line machine shape FR-002 renders, composed from the
      // real report (not the constant asserted against a copy of itself).
      expect(
        block,
        'run: preflight failed — 1 unit behaviour(s) cannot pass make:\n'
        '  U1 — lets the user add a todo with a title '
        '(no declared contract trace, fallback to FR-001)\n'
        'Suggested: fix routing in plan, or run `zfa tdd run --force` '
        'to skip preflight.',
      );
    },
  );

  test(
    'U-1482-3e: O(1) — the gate needs only the plan artifacts (no toolchain, no subprocess)',
    () async {
      // A bare root: no pubspec.yaml, no `bin/zfa.dart`, no
      // tdd-profile.md. A gate that spawned a step or resolved the
      // project toolchain could not return a finding here — the refusal
      // is pure file reads (SC-1: under one second, zero spawns).
      final bare = Directory.systemTemp.createTempSync('zfa_1482_bare_');
      addTearDown(() => bare.deleteSync(recursive: true));
      _seedList(bare, '1482-bare', _list());

      final report = await RoutingProvenancePreflight(
        projectRoot: bare.path,
        featureDir: p.join(bare.path, 'specs', '1482-bare'),
      ).check();

      expect(report.offending.map((f) => f.id), ['U1']);
      // And the vacuous predicate it reuses is the #1259 one — no
      // duplicated assertion logic (FR-006).
      expect(
        contentIsVacuousGreen('expect(a, isNot(isA<UnimplementedError>()));'),
        isTrue,
      );
    },
  );

  test(
    'U-1482-3f: a leftover lane plan beside a LEGACY list is ignored (no false refusal)',
    () async {
      // The list is a legacy single-file table (no `## Lane split`), so
      // its own row is declared. A stale `04-ENGINE.md` left on disk by
      // an earlier split must not be consulted — the meta-index guard
      // (issue #1000, the fail-open boundary).
      _seedList(root, '1482-preflight-fixture', '''
# Test List: 1482-preflight-fixture

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | formats the stored title | FR-001, Formatter.format | PENDING |

## Routing provenance

route: U1 -> unit lane (func surface) [declared: contract row Formatter.format]
''');
      _seedList(root, '1482-preflight-fixture', '''
# Engine Plan

## Routing provenance

route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
''', file: '04-ENGINE.md');

      final report = await gate('1482-preflight-fixture').check();

      expect(report.ok, isTrue, reason: report.offending.toString());
    },
  );

  test(
    'U-1482-3g: an unreadable test list fails open (no unhandled read error)',
    () async {
      _seedList(root, '1482-preflight-fixture', _list());
      final listFile = File(
        p.join(
          root.path,
          'specs',
          '1482-preflight-fixture',
          'tdd',
          'test-list.md',
        ),
      );
      await Process.run('chmod', ['000', listFile.path]);
      try {
        final report = await gate('1482-preflight-fixture').check();

        expect(
          report.ok,
          isTrue,
          reason:
              'an unreadable list must fail open — the driver names the '
              'real problem downstream, never an unhandled '
              'FileSystemException',
        );
        expect(report.offending, isEmpty);
      } finally {
        await Process.run('chmod', ['644', listFile.path]);
      }
    },
  );

  test(
    'U-1482-3h: an AC-only trace omits the fallback suffix (FR-002 FR-only shape)',
    () async {
      _seedList(root, '1482-preflight-fixture', '''
# Test List: 1482-preflight-fixture

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | syncs when the network returns | AC-2 | PENDING |

## Routing provenance

route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
''');

      final report = await gate('1482-preflight-fixture').check();

      // FR-002 renders `fallback to FR<id>` — an AC-shaped trace names no
      // FR, so the suffix is omitted (the row is still refused).
      expect(report.offending.single.criterionTraces, isEmpty);
      expect(
        report.offending.single.line,
        '  U1 — syncs when the network returns (no declared contract trace)',
      );
    },
  );

  test(
    'U-1482-3i: a provenance line off the unit lane is never a fallback',
    () async {
      // The gate's contract is the fallback-routed UNIT (FR-001): a
      // `route:` line naming another lane is not that shape, even for a
      // unit row id.
      _seedList(root, '1482-preflight-fixture', '''
# Test List: 1482-preflight-fixture

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | renders the brand theme | FR-011 | PENDING |

## Routing provenance

route: U1 -> widget lane [fallback: repairable — add `**Type**: widget` to the scenario]
''');

      final report = await gate('1482-preflight-fixture').check();

      expect(report.ok, isTrue, reason: report.offending.toString());
    },
  );
}
