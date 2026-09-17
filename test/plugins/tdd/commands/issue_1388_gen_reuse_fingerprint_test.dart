@Tags(['slow'])
// Issue #1388 — gen reuses stale guard-only artifacts after a traces:
// migration, defeating the recovery loop the vacuous-guard stop itself
// prescribes (add traces → re-plan → re-gen → re-run, issues
// #1259/#1308).
//
// The registry reuse decision reuses a prior record purely on
// behavior-id + paths + file existence; the #1320 staleness re-render
// only fires when the CURRENT render differs byte-wise — i.e. only when
// a declared SIGNATURE now resolves. A declared-routing change that
// does not alter the rendered bytes (a no-signature contract row — the
// exact 004-login-ui `adaptive_layouts` shape) leaves the pair
// `verdict=reused` and guard-only. A pair whose subject progressed past
// the stub stage exits the staleness path early (never clobber real
// work) and is reused too — the only escapes (`zfa tdd reset`,
// hand-delete + --adopt) are undocumented in gen's output.
//
// Fix under test: gen's reuse FINGERPRINT — sha256 over the resolved
// lane-plan traces cell + the spec's declared-routing surface (the Layer
// Contracts section — never the whole `spec.md`, so a documentation-only
// edit is not a routing change; issue #1388 review) — persisted per
// record (`gen_fingerprint`), gating the reuse path: drift → forced
// regeneration (stub pair; verdict=regenerated) or refusal naming
// `zfa tdd reset <feature>` (progressed/ffi pair).
//
// Behavior map:
//   U1 — signature-row traces migration: gen regenerates the pair, the
//        test carries the declared outcome assertion, and the gen
//        transcript carries no guard-only warning (pin: the #1320 path
//        composes with the fingerprint gate).
//   U2 — NO-signature-row traces migration (the issue's shape): gen
//        regenerates (verdict=regenerated) even though the rendered
//        bytes are identical; the stale guard-only pair is no longer
//        reported `reused`.
//   U3 — drift + progressed subject: reuse is REFUSED (exit 1) with
//        `--> fix: zfa tdd reset <feature>` naming the actual escape
//        hatch; the owned pair is never clobbered.
//   U4 — the fingerprint arms on created records (64-hex sha256 in the
//        registry JSON), is deterministic across identical routing
//        inputs, and distinguishes different routing inputs.
//   U5 — the drift fires ONCE per change: after a drift-driven
//        regeneration the stored fingerprint is refreshed and the next
//        gen is `reused` again.
//   U6 — genuinely unchanged routing and LEGACY records (no stored
//        fingerprint) keep byte-identical `reused` reuse — the gate
//        never breaks FR-006 idempotency for the unchanged class.
//   U7 — a documentation-only `spec.md` edit (reworded acceptance prose,
//        an appended comment; no re-plan) is NOT a routing change:
//        verdict=reused, the digest and the bytes do not move.
//   U7b — that same prose edit on a PROGRESSED pair reuses (exit 0) —
//        it never prescribes the destructive `zfa tdd reset`.
//   U8 — a Layer Contracts declaration that resolves no routing leaves
//        the render byte-identical and still forces the re-render
//        (verdict=regenerated, digest refreshed, reuse resumes).
library;

import 'dart:convert';
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

# Spec: 1388-repro

### Layer Contracts

**Domain**:
- `RouteContentType`: `contentType() -> String`

## Functional Requirements

- **FR-001**: System MUST expose the response content type
            traces: FR-001

## Acceptance Scenarios

1. **Given** a response **When** the header is read **Then** the content type is exposed.
''';

/// The migration the guard-only remedy prescribes: FR-001 now traces to
/// the declared single-method row — plan method-qualifies the cell
/// (#1320) and gen resolves the declared `contentType() -> String`
/// shape.
const signatureTracedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1388-repro

### Layer Contracts

**Domain**:
- `RouteContentType`: `contentType() -> String`

## Functional Requirements

- **FR-001**: System MUST expose the response content type
            traces: RouteContentType

## Acceptance Scenarios

1. **Given** a response **When** the header is read **Then** the content type is exposed.
''';

/// The issue's exact shape (#1377/#1388): FR-001 traces to a declared
/// Domain row that carries NO signature (a layout-surface row — the
/// `adaptive_layouts` class). The routing is DECLARED, but no signature
/// resolves, so the rendered pair is byte-identical to the guard-only
/// one — the #1320 byte-compare cannot see the change.
const noSignatureTracedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1388-repro

### Layer Contracts

**Domain**:
- `RouteFlags`: mobile, macos

## Functional Requirements

- **FR-001**: System MUST expose the response content type
            traces: RouteFlags

## Acceptance Scenarios

1. **Given** a response **When** the header is read **Then** the content type is exposed.
''';

/// Documentation-only edits to [selfTracedSpec]: the acceptance prose is
/// reworded and a comment is appended. Nothing here declares routing, so
/// the pair gen owns is not stale — the fingerprint must not move
/// (issue #1388 review: hashing the whole `spec.md` made every prose edit
/// read as a declared-routing change).
const proseOnlyEditedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1388-repro

### Layer Contracts

**Domain**:
- `RouteContentType`: `contentType() -> String`

## Functional Requirements

- **FR-001**: System MUST expose the response content type
            traces: FR-001

## Acceptance Scenarios

1. **Given** a response **When** the reader asks for the header **Then** the
   content type is exposed.

<!-- typo fix in prose, no routing change -->
''';

/// A declaration added to the Layer Contracts section that no behavior's
/// traces cell resolves: the declared-routing SURFACE changed, but the
/// resolved cell (and therefore the rendered pair) is byte-identical.
/// Pins the forceRebuild leg — the drift is the routing's, not the
/// render's (issue #1388 review).
const routingSurfaceEditedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1388-repro

### Layer Contracts

**Domain**:
- `RouteContentType`: `contentType() -> String`
- `UnrelatedShape`: `id() -> String`

## Functional Requirements

- **FR-001**: System MUST expose the response content type
            traces: FR-001

## Acceptance Scenarios

1. **Given** a response **When** the header is read **Then** the content type is exposed.
''';

/// Anchor a registry-recorded artifact path against the fixture root
/// (post-#1397 records carry the project-relative POSIX form).
String fixturePath(TddFixture fx, String recordedPath) =>
    p.isAbsolute(recordedPath)
    ? recordedPath
    : p.join(fx.root.path, recordedPath);

/// Plan + first gen for [specMd]: the untraced guard-only pair whose
/// registry record arms the reuse gate under test.
Future<({String genOut, Map<String, dynamic> record, String testContent})>
seedGuardOnlyPair(CliRunner runner, TddFixture fx, String specMd) async {
  await Directory(fx.featureDir).create(recursive: true);
  await File(p.join(fx.featureDir, 'spec.md')).writeAsString(specMd);
  await runner.runCapturing([
    'tdd',
    'plan',
    '1388-repro',
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

/// Re-write the spec and re-run plan (the migration step the guard-only
/// remedy prescribes), then re-run gen and return its transcript.
Future<String> migrateAndGen(
  CliRunner runner,
  TddFixture fx,
  String specMd,
) async {
  await File(p.join(fx.featureDir, 'spec.md')).writeAsString(specMd);
  await runner.runCapturing([
    'tdd',
    'plan',
    '1388-repro',
    '--project',
    fx.root.path,
  ]);
  return runner.runCapturing(['tdd', 'gen', 'U1', '--project', fx.root.path]);
}

/// Strip `gen_fingerprint` from [id]'s record — simulating a record
/// written by a pre-#1388 binary (the field is OPTIONAL for exactly
/// this shape).
Future<void> stripFingerprint(TddFixture fx, String id) async {
  final file = File(fx.artifactsPath);
  final doc = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final records = (doc['records'] as List).cast<Map<String, dynamic>>();
  for (final record in records) {
    if (record['behavior_id'] == id) {
      record.remove('gen_fingerprint');
    }
  }
  await file.writeAsString(jsonEncode(doc));
}

void main() {
  group(
    'issue #1388 — gen reuse fingerprint invalidates on routing change',
    () {
      late TddFixture fx;
      final runner = CliRunner(exitOnCompletion: false);

      setUp(() async {
        fx = await TddFixture.create(featureName: '1388-repro');
      });

      tearDown(() {
        fx.dispose();
        exitCode = 0;
      });

      test('U1: signature-row traces migration regenerates the pair with '
          'the declared assertion and no guard-only warning', () async {
        final seeded = await seedGuardOnlyPair(runner, fx, selfTracedSpec);
        expect(
          contentIsVacuousGreen(seeded.testContent),
          isTrue,
          reason: 'the untraced pair is the guard-only candidate',
        );

        final second = await migrateAndGen(runner, fx, signatureTracedSpec);
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
          isNot(contains(vacuousGuardWarningToken)),
          reason:
              'the regenerated pair derives a real outcome assertion — no '
              'guard-only warning may survive the migration:\n$second',
        );
        final after = await fx.registryRecordOf('U1');
        final testAfter = await File(
          fixturePath(fx, after['test_path'] as String),
        ).readAsString();
        expect(
          testAfter,
          contains('expect(result, isA<String>())'),
          reason: 'the regenerated test asserts the DECLARED outcome',
        );
        expect(
          contentCarriesVacuousGuardMarker(testAfter),
          isFalse,
          reason: 'the regenerated test carries no guard-only marker',
        );
      });

      test('U2: no-signature-row traces migration regenerates the pair and '
          'reports verdict=regenerated (the issue shape)', () async {
        final seeded = await seedGuardOnlyPair(runner, fx, selfTracedSpec);
        expect(
          contentIsVacuousGreen(seeded.testContent),
          isTrue,
          reason: 'the untraced pair is the guard-only candidate',
        );

        final second = await migrateAndGen(runner, fx, noSignatureTracedSpec);
        expect(exitCode, 0, reason: 'the re-gen must succeed: $second');
        expect(
          second,
          contains('verdict=regenerated'),
          reason:
              'the declared routing changed for U1 (the traces cell gained '
              'a no-signature row) — gen must invalidate the reuse through '
              'the front door instead of reporting the stale guard-only '
              'pair `reused` (issue #1388):\n$second',
        );
        final after = await fx.registryRecordOf('U1');
        final testAfter = await File(
          fixturePath(fx, after['test_path'] as String),
        ).readAsString();
        // The render keeps the guard-only SHAPE (a no-signature row
        // resolves no declared outcome — the #1420 class) but reflects the
        // CURRENT routing: the criterion echo carries the migrated cell.
        expect(
          contentIsVacuousGreen(testAfter),
          isTrue,
          reason:
              'no signature resolves for the no-signature row — the pair '
              'stays the honest guard shape',
        );
        expect(
          testAfter,
          contains("group('U1 (FR-001, RouteFlags)'"),
          reason:
              'the regenerated pair reflects the CURRENT traces cell, not '
              'the one the pair was generated under',
        );
        expect(
          contentCarriesVacuousGuardMarker(testAfter),
          isFalse,
          reason: 'the unit fallback pair never carries the marker',
        );
      });

      test('U3: drift + progressed subject refuses reuse naming '
          '`zfa tdd reset` — the owned pair is never clobbered', () async {
        final seeded = await seedGuardOnlyPair(runner, fx, selfTracedSpec);

        // The subject progressed past the stub stage (real implementation
        // landed — body and its stub doc-comment rewritten, the shape the
        // #683 progressed-artifact rule protects).
        final subjectFile = File(
          fixturePath(fx, seeded.record['subject_path'] as String),
        );
        final progressed = (await subjectFile.readAsString())
            .replaceFirst(
              RegExp(r'=> throw UnimplementedError\([^;]*\);'),
              "=> 'text/event-stream';",
            )
            .replaceFirst(
              '/// Throws [UnimplementedError] until the real implementation '
                  "lands.\n",
              '',
            );
        expect(
          progressed.contains('UnimplementedError'),
          isFalse,
          reason:
              'the progressed subject must not mention the stub error at '
              'all — that is the guard the staleness machinery keys on',
        );
        await subjectFile.writeAsString(progressed);

        final second = await migrateAndGen(runner, fx, signatureTracedSpec);
        expect(
          exitCode,
          1,
          reason:
              'the drifted pair cannot be regenerated (progressed subject) '
              'and must not be reported `reused` — gen refuses:\n$second',
        );
        expect(second, contains('--> fix:'));
        expect(
          second,
          contains('zfa tdd reset 1388-repro'),
          reason:
              'the refusal names the ACTUAL escape hatch with the feature '
              'reference (issue #1388):\n$second',
        );
        expect(second, contains('verdict=refused'));

        // The owned pair is untouched: the refusal never clobbers real
        // work and never rewrites the registry record.
        final subjectAfter = await subjectFile.readAsString();
        expect(
          subjectAfter,
          contains("=> 'text/event-stream';"),
          reason: 'the progressed subject survives the refusal verbatim',
        );
        final after = await fx.registryRecordOf('U1');
        expect(
          after['test_path'],
          seeded.record['test_path'],
          reason: 'the registry record is unchanged by the refusal',
        );
      });

      test('U4: the fingerprint arms on created records — deterministic '
          'for identical routing, distinct for different routing', () async {
        final seeded = await seedGuardOnlyPair(runner, fx, selfTracedSpec);
        final fingerprint = seeded.record['gen_fingerprint'] as String?;
        expect(
          fingerprint,
          isNotNull,
          reason:
              'gen must persist the reuse fingerprint on the created '
              'record (issue #1388): '
              '${seeded.record.keys.toList()}',
        );
        expect(
          RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint!),
          isTrue,
          reason: 'the fingerprint is a sha256 hex digest: $fingerprint',
        );

        // Identical routing inputs (same spec, same traces cell) hash to
        // the same fingerprint in a fresh project.
        final twin = await TddFixture.create(featureName: '1388-repro');
        try {
          final twinSeeded = await seedGuardOnlyPair(
            runner,
            twin,
            selfTracedSpec,
          );
          expect(
            twinSeeded.record['gen_fingerprint'],
            fingerprint,
            reason:
                'the fingerprint is a pure function of the routing '
                'inputs (traces cell + spec.md), not of the project',
          );
        } finally {
          twin.dispose();
        }

        // A different routing input hashes differently.
        final migrated = await migrateAndGen(runner, fx, signatureTracedSpec);
        expect(migrated, contains('verdict=regenerated'), reason: migrated);
        final after = await fx.registryRecordOf('U1');
        expect(
          after['gen_fingerprint'],
          isNot(fingerprint),
          reason:
              'the traces migration changed the routing inputs — the '
              'stored fingerprint must differ after the regeneration',
        );
      });

      test('U5: the drift fires ONCE per change — the refreshed '
          'fingerprint reuses again', () async {
        await seedGuardOnlyPair(runner, fx, selfTracedSpec);

        final second = await migrateAndGen(runner, fx, signatureTracedSpec);
        expect(
          second,
          contains('verdict=regenerated'),
          reason: 'the migration must invalidate the reuse:\n$second',
        );

        final third = await runner.runCapturing([
          'tdd',
          'gen',
          'U1',
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 0, reason: 'the third gen must succeed: $third');
        expect(
          third,
          contains('verdict=reused'),
          reason:
              'the regeneration refreshed the stored fingerprint — the '
              'drift fires once per routing change and stable reuse '
              'resumes (FR-006 idempotency):\n$third',
        );
      });

      test('U6: unchanged routing and legacy records keep byte-identical '
          'reuse', () async {
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
              'genuinely unchanged routing must keep the FR-006 reuse '
              'idempotency (issue #1388 must not break it):\n$second',
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

        // A record written by a pre-#1388 binary carries no fingerprint:
        // the gate stays open for it (no mass invalidation of shipped
        // registries).
        await stripFingerprint(fx, 'U1');
        final third = await runner.runCapturing([
          'tdd',
          'gen',
          'U1',
          '--project',
          fx.root.path,
        ]);
        expect(
          exitCode,
          0,
          reason: 'the legacy-record gen must succeed: $third',
        );
        expect(
          third,
          contains('verdict=reused'),
          reason:
              'legacy records without gen_fingerprint keep reusing — the '
              'fingerprint arms going forward, it never retro-invalidates:\n'
              '$third',
        );
      });

      test('U7: a documentation-only spec edit is not a routing change — '
          'the pair is reused, the digest does not move', () async {
        final seeded = await seedGuardOnlyPair(runner, fx, selfTracedSpec);

        // Edit spec.md ONLY (no `tdd plan`): the acceptance prose is
        // reworded and a comment is appended. Nothing here declares
        // routing, so the pair gen owns is not stale.
        await File(
          p.join(fx.featureDir, 'spec.md'),
        ).writeAsString(proseOnlyEditedSpec);

        final second = await runner.runCapturing([
          'tdd',
          'gen',
          'U1',
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 0, reason: 'a prose edit is not a failure: $second');
        expect(
          second,
          contains('verdict=reused'),
          reason:
              'the spec component of the fingerprint is the declared-'
              'routing surface (Layer Contracts) — prose that resolves no '
              'routing must not read as a declared-routing change '
              '(issue #1388 review):\n$second',
        );
        expect(
          second,
          isNot(contains('declared routing changed')),
          reason: 'no false "declared routing changed" note:\n$second',
        );
        final after = await fx.registryRecordOf('U1');
        expect(
          after['gen_fingerprint'],
          seeded.record['gen_fingerprint'],
          reason: 'a documentation-only edit must not move the digest',
        );
        final testAfter = await File(
          fixturePath(fx, after['test_path'] as String),
        ).readAsString();
        expect(
          testAfter,
          seeded.testContent,
          reason: 'the reuse is byte-identical',
        );
      });

      test('U7b: a prose-only spec edit on a PROGRESSED pair reuses — it '
          'never prescribes the destructive `zfa tdd reset`', () async {
        final seeded = await seedGuardOnlyPair(runner, fx, selfTracedSpec);

        // The subject progressed past the stub stage — the shape where a
        // fingerprint drift used to hard-fail with a remedy that deletes
        // the implementation.
        final subjectFile = File(
          fixturePath(fx, seeded.record['subject_path'] as String),
        );
        final progressed = (await subjectFile.readAsString())
            .replaceFirst(
              RegExp(r'=> throw UnimplementedError\([^;]*\);'),
              "=> 'text/event-stream';",
            )
            .replaceFirst(
              '/// Throws [UnimplementedError] until the real implementation '
                  "lands.\n",
              '',
            );
        await subjectFile.writeAsString(progressed);

        await File(
          p.join(fx.featureDir, 'spec.md'),
        ).writeAsString(proseOnlyEditedSpec);

        final second = await runner.runCapturing([
          'tdd',
          'gen',
          'U1',
          '--project',
          fx.root.path,
        ]);
        expect(
          exitCode,
          0,
          reason:
              'a prose edit must never fail a gen run, however the pair is '
              'shaped (issue #1388 review):\n$second',
        );
        expect(
          second,
          contains('verdict=reused'),
          reason: 'the pair is not stale — nothing it renders moved:\n$second',
        );
        expect(
          second,
          isNot(contains('--> fix: zfa tdd reset')),
          reason:
              'the destructive remedy is for a genuine declared-routing '
              'change, never for a documentation edit:\n$second',
        );
        expect(
          await subjectFile.readAsString(),
          progressed,
          reason: 'the progressed subject survives verbatim',
        );
      });

      test('U8: a routing-surface declaration that leaves the render '
          'byte-identical still forces the re-render (forceRebuild)', () async {
        final seeded = await seedGuardOnlyPair(runner, fx, selfTracedSpec);

        // Edit spec.md ONLY (no `tdd plan`): a Layer Contracts row is
        // added that no behavior's traces cell resolves. The writers
        // render from the resolved cell, so the pair's bytes stay
        // identical — only the declared-routing surface moved. Without
        // forceRebuild the byte-equality short-circuit would keep the
        // stored pair and report `reused`.
        await File(
          p.join(fx.featureDir, 'spec.md'),
        ).writeAsString(routingSurfaceEditedSpec);

        final second = await runner.runCapturing([
          'tdd',
          'gen',
          'U1',
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 0, reason: 'the re-render must succeed: $second');
        expect(
          second,
          contains('verdict=regenerated'),
          reason:
              'the drift is the ROUTING\'s, not the render\'s — the '
              'byte-equality short-circuit must not keep a pair that '
              'predates a declared-routing-surface change:\n$second',
        );
        final after = await fx.registryRecordOf('U1');
        final testAfter = await File(
          fixturePath(fx, after['test_path'] as String),
        ).readAsString();
        expect(
          testAfter,
          seeded.testContent,
          reason:
              'the render is byte-identical — exactly the drift the '
              'byte-compare cannot see',
        );
        expect(
          after['gen_fingerprint'],
          isNot(seeded.record['gen_fingerprint']),
          reason:
              'the drift is consumed once: the stored digest refreshes and '
              'the next gen reuses again',
        );

        final third = await runner.runCapturing([
          'tdd',
          'gen',
          'U1',
          '--project',
          fx.root.path,
        ]);
        expect(
          third,
          contains('verdict=reused'),
          reason: 'stable reuse resumes after the refresh:\n$third',
        );
      });
    },
  );
}
