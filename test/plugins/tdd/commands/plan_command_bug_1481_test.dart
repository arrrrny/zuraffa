// Bug #1481: `zfa tdd plan` writes the `**Type**` markers into spec.md
// and then reports those same behaviors as missing them in the SAME
// invocation — the routing verdict is computed from the PRE-emission
// parse, so the one-shot migration is invisible to the routing pass
// that reports on it. The author is told to add markers the run just
// wrote, and only a SECOND run tells the truth.
//
// Secondary: the acceptance lane self-heals via the migration while the
// unit lane never can (a contract-row trace cannot be invented by the
// classifier) — yet both rendered the identical
// `[fallback: legacy description classifier matched — ...]` prefix, so
// a transient self-healing condition and a permanently fatal one were
// indistinguishable (and plan exits 0 in both).
//
// The fix (plan_command.dart ONLY):
//   1. when the emitter migrated the spec, the provenance is
//      RE-DERIVED from the migrated content — a single invocation
//      reports the post-migration truth
//      (`[declared: type marker, spec line N]`);
//   2. the mutation is announced: `wrote N `**Type**` marker(s) into
//      spec.md` (and the stale "Re-run `zfa tdd plan`" advice is gone —
//      no re-run is needed);
//   3. the two fallback classes rendered differently: `[fallback:
//      repairable — ...]` vs `[fallback: no declared trace — make will
//      dead-end; ...]`, plus a one-line dead-end tally so the author
//      need not scan every route line.
//
// Feature #1484 update: the FATAL unit-fallback class no longer exists
// for unbound FRs — an FR with no surviving `traces:` binding routes to
// a manual declaration (with its own per-FR warning) instead of a unit
// route line, so the group below asserts the post-1484 contract: the
// manual-declaration warnings are rendered, no unit route line is
// emitted, and the dead-end tally is gone for manual-routed FRs.
//
// SPEC 1537 update (issue #1537): the fatal class is NOT fully retired —
// it is LIVE for criterion-only trace bindings (`traces: FR-001`, the
// resolver's criterion-token skip), reachable via the persistence-marked
// exemption or `--allow-unit-fallback`. The earlier "out of reach" note
// above is true only for the no-binding default; the `#1537` group at the
// end of this file pins the live machinery (proven red against a deletion
// mutant, green on HEAD).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// A speckit-shaped spec: the scenario carries NO `**Type**` marker
/// (the only fallback target — repairable), and the FR is traced to a
/// declared Layer Contracts row (so the unit lane is declared — zero
/// dead-ends).
const _healableSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1481-route

## Layer Contracts

**Function**:
- `Formatter`: `format(Template) -> String`

## Functional Requirements

- **FR-001**: the label renders the template
            traces: Formatter.format

## Acceptance Scenarios

1. **Given** the app **When** the total is requested **Then** the total equals the sum of items.
''';

/// A spec whose FRs carry no `traces:` binding (and no Layer Contracts
/// section exists to trace to): feature #1484 routes them to manual
/// declarations, so no unit lane row is emitted at all.
const _unboundFrSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1481-route

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args
- **FR-002**: persists the draft when saved

## Acceptance Scenarios

1. **Given** the app **When** the total is requested **Then** the total equals the sum of items.
''';

Future<Directory> _featureDir(String spec) async {
  final tmp = Directory.systemTemp.createTempSync('bug1481_');
  final featureDir = p.join(tmp.path, 'specs', '1481-route');
  await Directory(featureDir).create(recursive: true);
  await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
  return tmp;
}

Future<String> _plan(Directory tmp, [List<String> extra = const []]) async {
  final runner = CliRunner(exitOnCompletion: false);
  final out = await runner.runCapturing([
    'tdd',
    'plan',
    '1481-route',
    '--project',
    tmp.path,
    ...extra,
  ]);
  return out;
}

File _specFile(Directory tmp) =>
    File(p.join(tmp.path, 'specs', '1481-route', 'spec.md'));

/// The `--json` verdict.v1 envelope — the final captured-output line by
/// contract (the flag help names it). Anchored on the last NON-EMPTY line:
/// scanning for a `{`-shaped line would silently decode a human output
/// line that merely starts with `{` (review of #1537). The schema stamp is
/// asserted here so every caller reads a canonical envelope.
Map<String, dynamic> _verdictEnvelope(String out) {
  final line = out
      .split('\n')
      .map((l) => l.trim())
      .lastWhere(
        (l) => l.isNotEmpty,
        orElse: () => fail('no verdict.v1 envelope on stdout'),
      );
  final decoded = jsonDecode(line) as Map<String, dynamic>;
  expect(decoded['schema'], 'zuraffa.verdict.v1');
  return decoded;
}

void main() {
  group('#1481: one plan invocation reports the post-migration truth', () {
    test(
      'a single run routes the just-migrated scenario '
      '[declared: type marker], not [fallback: ... add `**Type**`]',
      () async {
        final tmp = await _featureDir(_healableSpec);
        try {
          final out = await _plan(tmp);
          expect(exitCode, 0, reason: out);
          // The verdict reflects the spec state as of the END of the
          // invocation — the marker this run wrote is what routes A1.
          expect(
            out,
            contains('route: A1 -> acceptance lane [declared: type marker'),
            reason: 'single invocation must be truthful: $out',
          );
          expect(
            out,
            contains('spec line'),
            reason: 'the declared verdict names the migrated marker line',
          );
          // The stale advice — "add the marker" for a behavior the run
          // just repaired — is gone.
          expect(
            out,
            isNot(contains('add `**Type**: acceptance` to the scenario')),
            reason: 'the author must not be told to add what is there',
          );
          // And the spec on disk really was migrated.
          expect(
            await _specFile(tmp).readAsString(),
            contains('**Type**: acceptance'),
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      },
    );

    test('the rendered test-list carries the same post-migration '
        'verdict (artifact and stdout agree)', () async {
      final tmp = await _featureDir(_healableSpec);
      try {
        final out = await _plan(tmp);
        expect(exitCode, 0, reason: out);
        final list = await File(
          p.join(tmp.path, 'specs', '1481-route', 'tdd', 'test-list.md'),
        ).readAsString();
        expect(
          list,
          contains('route: A1 -> acceptance lane [declared: type marker'),
          reason: 'the durable artifact matches the reported verdict',
        );
        expect(list, isNot(contains('[fallback:')));
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('the second run writes zero new markers (the migration is '
        'one-time; no repeat announcement)', () async {
      final tmp = await _featureDir(_healableSpec);
      try {
        await _plan(tmp);
        final out = await _plan(tmp);
        expect(exitCode, 0, reason: out);
        expect(out, contains('[declared: type marker'));
        expect(out, isNot(contains('[fallback:')));
        expect(
          out,
          isNot(contains('marker(s) into spec.md')),
          reason: 'nothing was migrated on the second run',
        );
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });

  group('#1481: the mutation is announced', () {
    test('plan prints `wrote N `**Type**` marker(s) into spec.md` and '
        'no longer advises a re-run', () async {
      final tmp = await _featureDir(_healableSpec);
      try {
        final out = await _plan(tmp);
        expect(exitCode, 0, reason: out);
        expect(out, contains('wrote 1 `**Type**` marker(s) into spec.md'));
        expect(
          out,
          isNot(contains('Re-run `zfa tdd plan`')),
          reason: 'one run is sufficient — the stale advice is retired',
        );
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });

  group('#1481: manual routing replaced the fatal unit-fallback class', () {
    test(
      'an unbound FR routes to a manual declaration (no unit route '
      'line, no fallback class) while the scenario heals to declared',
      () async {
        final tmp = await _featureDir(_unboundFrSpec);
        try {
          final out = await _plan(tmp);
          expect(exitCode, 0, reason: out);
          // Feature 1484: an FR with no surviving `traces:` binding is
          // announced as a manual declaration — the pre-1484 fatal unit
          // fallback class is gone for unbound FRs.
          expect(
            out,
            contains('WARNING: FR-001 derives no unit behaviour'),
            reason: 'the unbound FR is announced: $out',
          );
          expect(
            out,
            contains('recorded as a manual declaration in tdd/traceability.md'),
            reason: 'the routing destination is named: $out',
          );
          // The warning names a durable artifact — assert the artifact,
          // not just the promise (same contract as the test-list.md
          // agreement test above).
          expect(
            await File(
              p.join(tmp.path, 'specs', '1481-route', 'tdd', 'traceability.md'),
            ).readAsString(),
            contains('manual (defaulted: no `traces:` binding)'),
            reason: 'the manual declaration is recorded, not just announced',
          );
          expect(
            out,
            contains('add a `traces:` line naming a declared contract row'),
            reason: 'the warning names the automated-route remedy',
          );
          expect(
            out,
            contains('add `**Type**: manual` under the FR'),
            reason: 'the warning names the explicit-exemption remedy',
          );
          // No unit route line is emitted — manual declarations never
          // render as unit-lane rows.
          expect(
            out,
            isNot(contains('route: U1')),
            reason: 'the manual-routed FR has no unit route line: $out',
          );
          expect(
            out,
            isNot(contains('route: U2')),
            reason: 'neither unbound FR has a unit route line: $out',
          );
          expect(
            out,
            isNot(contains('[fallback: no declared trace')),
            reason: 'the fatal fallback class is retired for unbound FRs',
          );
          // The acceptance scenario healed in the same invocation.
          expect(
            out,
            contains('route: A1 -> acceptance lane [declared: type marker'),
          );
          expect(
            await _specFile(tmp).readAsString(),
            contains('**Type**: acceptance'),
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      },
    );

    test('every unbound FR gets its own manual-declaration warning (no '
        'dead-end tally for manual-routed FRs)', () async {
      final tmp = await _featureDir(_unboundFrSpec);
      try {
        final out = await _plan(tmp);
        expect(exitCode, 0, reason: out);
        // Feature 1484: each unbound FR is announced individually —
        // manual-routed FRs never reach make as automated unit
        // behaviours, so the dead-end tally no longer applies.
        expect(
          out,
          contains('WARNING: FR-001 derives no unit behaviour'),
          reason: 'the first unbound FR is announced: $out',
        );
        expect(
          out,
          contains('WARNING: FR-002 derives no unit behaviour'),
          reason: 'the second unbound FR is announced: $out',
        );
        expect(
          out,
          isNot(contains('will dead-end at make')),
          reason:
              'no dead-end tally when every unit gap routes to a '
              'manual declaration: $out',
        );
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('the per-FR warning scales to PLURAL unbound FRs correctly', () async {
      final tmp = await _featureDir('''
**Template Version**: `zuraffa-1.0`

# Spec: 1481-route

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args
- **FR-002**: persists the draft when saved
- **FR-003**: validates the email format

## Acceptance Scenarios

1. **Given** the app **When** the total is requested **Then** the total equals the sum of items.
''');
      try {
        final out = await _plan(tmp);
        expect(exitCode, 0, reason: out);
        // Feature 1484: one manual-declaration warning per unbound FR,
        // no dead-end tally (manual-routed FRs never dead-end at make —
        // they are exempt from the automated unit lane).
        expect(
          out,
          contains('WARNING: FR-001 derives no unit behaviour'),
          reason: out,
        );
        expect(
          out,
          contains('WARNING: FR-002 derives no unit behaviour'),
          reason: out,
        );
        expect(
          out,
          contains('WARNING: FR-003 derives no unit behaviour'),
          reason: out,
        );
        expect(out, isNot(contains('will dead-end at make')), reason: out);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('a healable scenario under --no-emit-markers renders the '
        'REPAIRABLE class (not the fatal one)', () async {
      final tmp = await _featureDir(_healableSpec);
      try {
        final out = await _plan(tmp, ['--no-emit-markers']);
        expect(exitCode, 0, reason: out);
        expect(
          out,
          contains(
            'route: A1 -> acceptance lane [fallback: repairable — '
            'legacy description classifier matched',
          ),
          reason: 'the transient class is labeled: $out',
        );
        expect(
          out,
          contains('add `**Type**: acceptance` to the scenario'),
          reason: 'the repairable hint survives the opt-out',
        );
        expect(
          out,
          isNot(contains('will dead-end at make')),
          reason: 'no dead-end tally when nothing dead-ends',
        );
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });

  // SPEC 1537 (issue #1537): the fatal class is NOT retired — it is LIVE
  // through the criterion-token seam. An inline `traces:` line whose tokens
  // are all criterion-shaped (`FR-001` — the resolver's `_criterionToken`
  // skip) survives the `traceTokens` filter (only `(`-shaped tokens drop),
  // binds non-empty (so feature #1484 keeps the unit row instead of routing
  // a manual declaration), and passes the resolver without dangling —
  // `kind == null` -> `RoutingUndeclared` -> `decision == unit` ->
  // `!repairable` -> `deadEnds.add`. The #1480 unit-fallback gate hides the
  // route on the default path, but two live routes reach the machinery:
  // persistence-marked fallbacks are exempt from the gate, and
  // `--allow-unit-fallback` skips it. These tests PIN the machinery so the
  // next sweep cannot delete it as "dead code" on the strength of the
  // disproved unreachability analysis.
  //
  // Both render paths are pinned: P1-P3 walk the legacy single-file path,
  // P4 the `## Lanes` split — a SEPARATE verdict write (plan_command.dart
  // :1377 vs :1558) — so the deletion mutant's "both verdict keys" claim is
  // evidenced end to end (review of #1537).
  //
  // Two hermeticity caveats the pins inherit (review of #1537): the exit
  // reads use `CliRunner.lastDispatchedExitCode` — the per-isolate
  // snapshot — because `dart:io`'s `exitCode` is process-global and a
  // sibling suite can clobber it (cli_runner.dart:90-103); and
  // `runCapturing` returns ONE captured buffer (cli_runner.dart:654 —
  // zone-intercepted `print`, no per-stream API), so a `contains` proves
  // the line is emitted on the captured channel, not that stdout/stderr
  // are distinguishable.
  group(
    '#1537: the fatal dead-end machinery is LIVE (criterion-only trace bindings)',
    () {
      // The persistence route: default flags, no escape hatch — the #1480
      // gate exempts persistence-marked unit fallbacks.
      const persistentCriterionTraceSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1481-route

## Functional Requirements

- **FR-001**: [persistent] the label renders the template
            traces: FR-001

## Acceptance Scenarios

1. **Given** the app **When** the total is requested **Then** the total equals the sum of items.
''';

      // The flag route: no persistence mark, the gate explicitly waived.
      // Derived from the spec above so the pair cannot drift beyond the one
      // intended difference (review of #1537).
      final criterionTraceSpec = persistentCriterionTraceSpec.replaceFirst(
        '[persistent] ',
        '',
      );

      // The lane-split route (review of #1537): the SAME criterion-only
      // seam through the `## Lanes` render path. Every spec-derived behavior
      // must be declared in a lane (an undeclared id refuses before any
      // artifact), so CORE names both the scenario and the FR route. P4
      // (below) pins the split path's verdict write (plan_command.dart
      // :1377), the sibling of the legacy :1558 site the cases above pin.
      const laneSplitCriterionTraceSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1481-route

## Functional Requirements

- **FR-001**: [persistent] the label renders the template
            traces: FR-001

## Acceptance Scenarios

1. **Given** the app **When** the total is requested **Then** the total equals the sum of items.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1]
    flutter_allowed: false
```
''';

      test(
        'a persistence-marked FR with a criterion-only traces binding renders '
        'the fatal route line and the tally (default flags, exit 0)',
        () async {
          final tmp = await _featureDir(persistentCriterionTraceSpec);
          try {
            final out = await _plan(tmp);
            expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
            // The fatal-class route prefix renders for the unit fallback.
            expect(
              out,
              contains(
                'route: U1 -> unit lane [fallback: no declared trace — '
                'make will dead-end',
              ),
              reason: 'the fatal fallback class renders: $out',
            );
            // The one-line tally names the id — the author learns the plan
            // will dead-end without scanning every route line (bug #1481).
            expect(
              out,
              contains('zfa tdd plan: 1 behavior will dead-end at make'),
              reason: 'the fatal tally renders: $out',
            );
            expect(
              out,
              contains('(U1)'),
              reason: 'the tally names the dead-ended behavior id: $out',
            );
          } finally {
            tmp.deleteSync(recursive: true);
          }
        },
      );

      test('the flag route — --allow-unit-fallback reaches the same tally '
          'without the persistence mark', () async {
        final tmp = await _featureDir(criterionTraceSpec);
        try {
          final out = await _plan(tmp, ['--allow-unit-fallback']);
          expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
          expect(
            out,
            contains(
              'route: U1 -> unit lane [fallback: no declared trace — '
              'make will dead-end',
            ),
            reason: 'the fatal fallback class renders under the waiver: $out',
          );
          expect(
            out,
            contains('zfa tdd plan: 1 behavior will dead-end at make'),
            reason: 'the fatal tally renders under the waiver: $out',
          );
          expect(
            out,
            contains('(U1)'),
            reason: 'the tally names the dead-ended behavior id: $out',
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('the verdict envelope counts the dead end '
          '(dead_end_behaviors == 1)', () async {
        final tmp = await _featureDir(persistentCriterionTraceSpec);
        try {
          final out = await _plan(tmp, ['--json']);
          expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
          final verdict = _verdictEnvelope(out);
          final details = verdict['details'] as Map<String, dynamic>;
          expect(
            details['dead_end_behaviors'],
            1,
            reason: 'the machine-readable dead-end count rides the envelope',
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('the lane-split render path (## Lanes) renders the same fatal '
          'tally and verdict count as the legacy path', () async {
        final tmp = await _featureDir(laneSplitCriterionTraceSpec);
        try {
          final out = await _plan(tmp, ['--json']);
          expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
          // The split path's own route line and tally (the lane branch of
          // plan_command.dart) render the fatal class the same way.
          expect(
            out,
            contains(
              'route: U1 -> unit lane [fallback: no declared trace — '
              'make will dead-end',
            ),
            reason: 'the fatal fallback class renders in the split: $out',
          );
          expect(
            out,
            contains('zfa tdd plan: 1 behavior will dead-end at make'),
            reason: 'the fatal tally renders in the split path: $out',
          );
          expect(
            out,
            contains('(U1)'),
            reason: 'the tally names the dead-ended behavior id: $out',
          );
          // Anchor the run ON the split path: 04-ENGINE.md is the split's
          // exclusive product, so a silent fall-through to the legacy
          // render cannot leave this pin green against its subject — the
          // verdict write at plan_command.dart:1377.
          expect(
            File(
              p.join(tmp.path, 'specs', '1481-route', 'tdd', '04-ENGINE.md'),
            ).existsSync(),
            isTrue,
            reason: 'the run took the ## Lanes split render path: $out',
          );
          final verdict = _verdictEnvelope(out);
          final details = verdict['details'] as Map<String, dynamic>;
          expect(
            details['dead_end_behaviors'],
            1,
            reason:
                'the machine-readable dead-end count rides the split '
                'verdict write',
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });
    },
  );
}
