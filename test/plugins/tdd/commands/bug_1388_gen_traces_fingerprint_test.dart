// Issue #1388 — `zfa tdd gen` reuses a stale guard-only pair even after
// the traces migration: the recovery loop the vacuous-guard stop
// prescribes (add `traces:` → re-run plan → gen → run) could not take
// effect because gen's reuse decision ignored the changed traces cell.
//
// Fix under test (spec 1388-gen-traces-fingerprint): when the routing
// the pair was generated under differs from the current one (the
// #1388 reuse fingerprint — sha256 over the resolved lane-plan traces
// cell + the spec's Layer Contracts surface), the pair is REGENERATED —
// the stale guard-only test carries the new declared routing afterwards.
//
// Issue #1633: both behaviors bootstrap through a REAL plan + gen (the
// sibling suite's `seedGuardOnlyPair` shape). The previous version of
// this fixture seeded the registry by hand, which writes a record with
// no `gen_fingerprint` — and the #1388 gate deliberately keeps reuse
// for legacy records (the sibling's U6 contract) — so the drift these
// behaviors assert could never fire. A plan+gen-created record arms the
// fingerprint; the traces mutation below is then a genuine drift.
//
// Behaviors:
//   B1 — traces drift (the cell gains a contract token: `FR-007` →
//        `FR-007, adaptive_layouts` via a contracts/*.md trace) → the
//        regenerated test carries the new routing in its group.
//   B2 — no drift (gen again on unchanged routing) → the pair is
//        reused untouched (guard).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

import '../helpers/tdd_fixture.dart';

/// The untraced starting shape: the self-trace token binds the row (the
/// cell renders the bare criterion, feature 1484) and no contract token
/// derives a declared signature — the pair is the guard-only candidate.
const selfTracedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1388-traces

### Layer Contracts

**Domain**:
- `RouteContentType`: `contentType() -> String`

## Functional Requirements

- **FR-007**: System MUST create the Login entity with an email
            traces: FR-007

## Acceptance Scenarios

1. **Given** a login form **When** the email is set **Then** the Login
   entity is created.
''';

/// Anchor a registry-recorded artifact path against the fixture root
/// (post-#1397 records carry the project-relative POSIX form).
String fixturePath(TddFixture fx, String recordedPath) =>
    p.isAbsolute(recordedPath)
    ? recordedPath
    : p.join(fx.root.path, recordedPath);

/// The traces mutation the guard-only remedy prescribes, through the
/// DESIGNED hand-delta seam (the vacuous-guard stop names it: "hand-edit
/// the test list traces cell ... and re-run zfa tdd gen"): the cell
/// gains a layout-surface token (`FR-007` → `FR-007, adaptive_layouts`)
/// that resolves no signature, so the rendered pair's routing moved
/// while the Layer Contracts surface stayed put — the exact #1388 class
/// the byte-compare is blind to and a contracts/*.md trace cannot
/// express (an FR traced from BOTH spec.md and a contracts file refuses,
/// #1480).
Future<void> mutateTracesCell(TddFixture fx) async {
  final list = File(fx.testListPath);
  final md = await list.readAsString();
  const before =
      '| U1 | System MUST create the Login entity with an email '
      '| FR-007 | PENDING |';
  const after =
      '| U1 | System MUST create the Login entity with an email '
      '| FR-007, adaptive_layouts | PENDING |';
  expect(
    md,
    contains(before),
    reason:
        'the seeded cell is the bare '
        'self-traced criterion:\n$md',
  );
  await list.writeAsString(md.replaceFirst(before, after));
}

/// Real plan + first gen for [specMd]: the untraced guard-only pair
/// whose registry record arms the #1388 reuse fingerprint.
Future<({String genOut, Map<String, dynamic> record, String testContent})>
seedGuardOnlyPair(CliRunner runner, TddFixture fx, String specMd) async {
  await Directory(fx.featureDir).create(recursive: true);
  await File(p.join(fx.featureDir, 'spec.md')).writeAsString(specMd);
  await runner.runCapturing([
    'tdd',
    'plan',
    fx.featureName,
    '--allow-unit-fallback',
    '--project',
    fx.root.path,
  ]);
  final genOut = await runner.runCapturing([
    'tdd',
    'gen',
    'U1',
    '--project',
    fx.root.path,
  ]);
  final record = await fx.registryRecordOf('U1');
  final testContent = await File(
    fixturePath(fx, record['test_path'] as String),
  ).readAsString();
  return (genOut: genOut, record: record, testContent: testContent);
}

/// Apply the traces mutation (the designed hand-delta seam), then
/// re-run gen and return its transcript.
Future<String> migrateAndGen(CliRunner runner, TddFixture fx) async {
  await mutateTracesCell(fx);
  return runner.runCapturing(['tdd', 'gen', 'U1', '--project', fx.root.path]);
}

void main() {
  group(
    'bug #1388 — traces drift forces regeneration over an armed record',
    () {
      late TddFixture fx;
      final runner = CliRunner(exitOnCompletion: false);

      setUp(() async {
        fx = await TddFixture.create(featureName: '1388-traces');
      });

      tearDown(() {
        fx.dispose();
        exitCode = 0;
      });

      test(
        'B1: traces drift forces regeneration carrying the new routing',
        () async {
          final seeded = await seedGuardOnlyPair(runner, fx, selfTracedSpec);
          expect(
            seeded.record['gen_fingerprint'],
            isNotNull,
            reason:
                'the plan+gen-created record arms the #1388 reuse fingerprint '
                '(issue #1633 — the hand-seeded record this fixture used '
                'before carried none, so the drift below could never fire)',
          );
          expect(
            contentIsVacuousGreen(seeded.testContent),
            isTrue,
            reason: 'the untraced pair is the guard-only candidate',
          );
          expect(
            seeded.testContent,
            contains("group('U1 (FR-007)'"),
            reason: 'the seeded pair reflects the bare self-traced criterion',
          );

          final second = await migrateAndGen(runner, fx);
          expect(exitCode, 0, reason: 'the re-gen must succeed: $second');
          expect(
            second,
            contains('verdict=regenerated'),
            reason:
                'the traces cell gained a contract token — gen must '
                'regenerate, never report the stale pair reused:\n$second',
          );
          expect(
            second,
            contains('declared routing changed'),
            reason:
                'the drift is the #1388 fingerprint path — the forced '
                're-render names the routing change, not a render-byte '
                'change:\n$second',
          );
          final after = await fx.registryRecordOf('U1');
          final testAfter = await File(
            fixturePath(fx, after['test_path'] as String),
          ).readAsString();
          expect(
            testAfter,
            contains("group('U1 (FR-007, adaptive_layouts)'"),
            reason:
                'the regenerated test carries the NEW declared routing '
                '(the record criterion was FR-007 only)',
          );
          expect(
            after['gen_fingerprint'],
            isNot(seeded.record['gen_fingerprint']),
            reason:
                'the drift is consumed once: the stored digest refreshes and '
                'stable reuse resumes',
          );
        },
      );

      test('B2: no traces drift reuses the pair untouched (guard)', () async {
        final seeded = await seedGuardOnlyPair(runner, fx, selfTracedSpec);

        final second = await runner.runCapturing([
          'tdd',
          'gen',
          'U1',
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 0, reason: 'the second gen must succeed: $second');
        expect(
          second,
          contains('verdict=reused'),
          reason:
              'genuinely unchanged routing keeps the FR-006 reuse '
              'idempotency:\n$second',
        );
        expect(
          second,
          isNot(contains('declared routing changed')),
          reason: 'the registered criterion already matches the row:\n$second',
        );
        final afterReuse = await fx.registryRecordOf('U1');
        final testAfterReuse = await File(
          fixturePath(fx, afterReuse['test_path'] as String),
        ).readAsString();
        expect(
          testAfterReuse,
          seeded.testContent,
          reason: 'the reuse is byte-identical',
        );
      });
    },
  );
}
