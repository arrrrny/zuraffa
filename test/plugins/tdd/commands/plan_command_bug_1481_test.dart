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
//   3. the two fallback classes render differently: `[fallback:
//      repairable — ...]` vs `[fallback: no declared trace — make will
//      dead-end; ...]`, plus a one-line dead-end tally so the author
//      need not scan every route line.
library;

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

/// A spec whose unit lane CANNOT self-heal: FR-002 traces nothing (and
/// no Layer Contracts section exists to trace to), so U1 stays
/// fallback-routed forever — the fatal class.
const _deadEndSpec = '''
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

  group('#1481: the two fallback classes are distinguishable', () {
    test('a unit fallback renders the FATAL class (no declared trace, '
        'make will dead-end) while the scenario heals to declared', () async {
      final tmp = await _featureDir(_deadEndSpec);
      try {
        final out = await _plan(tmp);
        expect(exitCode, 0, reason: out);
        expect(
          out,
          contains(
            'route: U1 -> unit lane [fallback: no declared trace — '
            'make will dead-end',
          ),
          reason: 'the fatal class must be unmistakable: $out',
        );
        expect(
          out,
          contains('trace FR to a declared contract row'),
          reason: 'the fatal class still names the remedy',
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
    });

    test('a single summary line tallies the dead-end behaviors (no '
        'scanning 42 route lines)', () async {
      final tmp = await _featureDir(_deadEndSpec);
      try {
        final out = await _plan(tmp);
        expect(exitCode, 0, reason: out);
        expect(
          out,
          contains(
            '2 behaviors will dead-end at make — no declared contract '
            'trace (U1, U2)',
          ),
          reason: 'the tally names the dead-ending ids: $out',
        );
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('the tally counts PLURAL dead-ends correctly', () async {
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
        expect(
          out,
          contains(
            '3 behaviors will dead-end at make — no declared contract '
            'trace (U1, U2, U3)',
          ),
          reason: out,
        );
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
}
