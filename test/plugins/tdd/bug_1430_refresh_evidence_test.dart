@Tags(['slow'])
// Issue #1430 — the refactor pass invalidates the green evidence it just
// certified: make certifies green with a `subject-hash` fingerprint, then
// the fixed pass registry (`zfa build` → `dart format lib/` →
// `dart fix --apply lib/`) rewrites the certified subject without
// refreshing the evidence, so every resume refuses `subject-drift
// (stale-artifacts)` and the loop dead-ends on the state it manufactured.
//
// Contract under test (spec 1430-refactor-refresh-evidence, FR-001..006):
//   A-1430-1  a green re-proof over a rewritten certified subject lets the
//             resume's make skip transition ACCEPT (provenance note), no
//             manual `--re-certify`;
//   A-1430-2  after the pass, the last subject-hash evidence for a touched
//             certified behavior equals the on-disk subject;
//   A-1430-3  an out-of-band post-certification edit still refuses
//             byte-identically (guard pin — green pre-fix, must stay green);
//   U-1430-1  the pass appends per-behavior `refresh` entries carrying the
//             post-rewrite hash and forces the FULL re-proof when a
//             certified subject was rewritten;
//   U-1430-2  a refused/misfired refactor reconciles nothing;
//   U-1430-3  a pass touching no certified subject writes exactly today's
//             evidence (byte-equality pin);
//   U-1430-4  a not-certified behavior's rewritten subject lands no refresh;
//   U-1430-5  several certified subjects rewritten in one pass → one
//             refresh entry per behavior;
//   U-1430-6  freshness + neighbor guards: a refresh older than the live
//             green refuses, a refresh whose hash ≠ current refuses, and
//             the #1162 fail-open / born-green refusal neighbors are
//             unchanged.
//
// Drives the real CLI (`zfa tdd refactor` / `zfa tdd make`) against real
// temp fixture projects (TddFixture); preflight, re-proof, and the make
// drift child execute REAL `dart test` subprocesses; the build pass is
// pinned to the fixture's fake zfa via --zfa-bin (bug #689 convention
// shared with bug_1311_refactor_receipt_refresh_test.dart).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/cycle_evidence.dart';

import 'helpers/tdd_fixture.dart';

Future<String> sha256Of(String path) async =>
    crypto.sha256.convert(await File(path).readAsBytes()).toString();

/// A subject `dart format` will REWRITE (the pass creates the drift the
/// issue describes). `return 42;` is not a born-green placeholder body.
String malformedSubject(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return 'library;\n\nint $symbol(){\nreturn 42;\n}\n';
}

/// Byte-identical to `dart format`'s output for [malformedSubject] — a
/// format no-op, so the pass touches nothing.
String formattedSubject(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return 'int $symbol() {\n  return 42;\n}\n';
}

/// A hand implementation (the #1162 sanctioned state — not a placeholder).
String handImplementedSubject(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
// Hand-implemented per the paired test header's instruction.
library;

int $symbol() {
  final base = 40;
  final step = 2;
  return base + step;
}
''';
}

/// The gen-shaped THROWING stub (a born-green placeholder class).
String throwingSubject(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
// GENERATED STUB — `zfa tdd gen $id`.
library;

int $symbol() => throw UnimplementedError('$symbol not implemented');
''';
}

/// Append a cycle-log section the real writers' shape carries, with
/// explicit control over the fields the guard reads (`subject-hash`, `at`).
/// Hand-seeded entries are legacy schema-0 (no chain lines) — the guard's
/// `lastEntryFor` reads them exactly like appended ones.
Future<void> seedHashedEvidence(
  TddFixture fx, {
  required String id,
  required String kind,
  String? subjectHash,
  String at = '2026-08-30T00:00:00.000Z',
  String criterion = 'FR-007',
}) async {
  final file = File(fx.cycleLogPath);
  if (!await file.exists()) {
    await file.parent.create(recursive: true);
    await file.writeAsString('# Cycle Log\n\n');
  }
  final hashLine = subjectHash == null ? '' : '- subject-hash: $subjectHash\n';
  await file.writeAsString(
    '## Cycle: $id ($kind)\n\n'
    '- behavior: $id\n'
    '- kind: $kind\n'
    '${kind == 'red' ? '- classification: assertionFailure\n' : ''}'
    '$hashLine'
    '- criterion: $criterion\n'
    '- test: ${fx.testPathOf(id)}\n'
    '- command: `dart test ${fx.testPathOf(id)}`\n'
    '- exit: ${kind == 'red' ? 1 : 0}\n'
    '- at: $at\n\n',
    mode: FileMode.append,
  );
}

/// Register [id] with a passing target test and a subject file on disk
/// carrying [subjectContent], plus (when [certified]) the certified
/// red+green evidence pair — the red make's precondition demands, the
/// green stamped with the subject's CURRENT hash — the post-make state
/// issue #1430 starts from.
Future<void> seedCertifiedGreen(
  TddFixture fx, {
  required String id,
  required String subjectContent,
  bool certified = true,
  String at = '2026-08-30T00:00:00.000Z',
}) async {
  await fx.registerBehavior(
    id: id,
    description: 'the $id behavior',
    testContent: TddFixture.greenTest('the $id behavior'),
  );
  final subjectFile = File(fx.subjectPathOf(id));
  await subjectFile.parent.create(recursive: true);
  await subjectFile.writeAsString(subjectContent);
  if (certified) {
    // The lifecycle red (make refuses without certified-red evidence);
    // hashless — the green entry below is the guard's basis.
    await seedHashedEvidence(fx, id: id, kind: 'red', at: at);
    await seedHashedEvidence(
      fx,
      id: id,
      kind: 'green',
      subjectHash: await sha256Of(subjectFile.path),
      at: at,
    );
  }
}

List<String> refactorArgs(TddFixture fx) => [
  'tdd',
  'refactor',
  '--project',
  fx.root.path,
  '--feature',
  fx.featureName,
  '--zfa-bin',
  fx.fakeZfaBin,
];

List<String> makeArgs(TddFixture fx, String id) => [
  'tdd',
  'make',
  '--project',
  fx.root.path,
  id,
];

void main() {
  late TddFixture fx;
  final runner = CliRunner(exitOnCompletion: false);

  setUp(() async {
    fx = await TddFixture.create();
    await fx.writeFakeZfa();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group(
    'issue #1430 — the pass re-binds the certified shape (A-1430-1/2, U-1430-1)',
    () {
      test(
        'A-1430-1: a green re-proof over the rewritten certified subject lets '
        'the resume make skip transition accept (no manual --re-certify)',
        () async {
          await seedCertifiedGreen(
            fx,
            id: 'A1',
            subjectContent: malformedSubject('A1'),
          );
          final certifiedHash = await sha256Of(fx.subjectPathOf('A1'));

          // The sanctioned pass rewrites the certified subject and re-proofs
          // green (the issue's exact sequence).
          final refactorOut = await runner.runCapturing(refactorArgs(fx));
          expect(
            refactorOut,
            contains(
              RegExp(r'refactor: feature=\S+ outcome=(clean|refactored)'),
            ),
            reason: 'refactor output:\n$refactorOut',
          );
          expect(exitCode, 0, reason: refactorOut);
          final rewrittenHash = await sha256Of(fx.subjectPathOf('A1'));
          expect(
            rewrittenHash,
            isNot(certifiedHash),
            reason: 'the format pass must really rewrite the subject',
          );

          // The resume: the make skip transition on the reformatted subject.
          // Pre-fix this refuses `subject-drift` (the dead end); post-fix the
          // refresh consult accepts with the provenance note.
          final makeOut = await runner.runCapturing(makeArgs(fx, 'A1'));
          expect(exitCode, 0, reason: 'make output:\n$makeOut');
          expect(makeOut, contains('outcome=skipped'), reason: makeOut);
          expect(makeOut, contains('issue #1430'), reason: makeOut);
          expect(
            makeOut,
            isNot(contains('the target test already passes, but the subject')),
            reason:
                'the #1036 refusal must not stand for loop-caused drift:\n'
                '$makeOut',
          );
        },
      );

      test('A-1430-2: after the pass the last subject-hash evidence for the '
          'touched certified behavior equals the on-disk subject', () async {
        await seedCertifiedGreen(
          fx,
          id: 'A1',
          subjectContent: malformedSubject('A1'),
        );

        final out = await runner.runCapturing(refactorArgs(fx));
        expect(exitCode, 0, reason: out);

        final diskHash = await sha256Of(fx.subjectPathOf('A1'));
        final entries = await CycleEvidence(fx.featureDir).entries();
        final hashed = entries
            .where((e) => e.behaviorId == 'A1' && e.subjectHash != null)
            .toList();
        expect(hashed, isNotEmpty, reason: 'evidence exists:\n$out');
        expect(
          hashed.last.subjectHash,
          diskHash,
          reason:
              'the certified evidence must agree with the disk the pass '
              'rewrote (last hashed entry: ${hashed.last.kind})',
        );
      });

      test('U-1430-1: the pass appends a refresh entry with the post-rewrite '
          'hash, witnessed by a re-proof whose scope covers the tested '
          'behavior', () async {
        await seedCertifiedGreen(
          fx,
          id: 'A1',
          subjectContent: malformedSubject('A1'),
        );

        final out = await runner.runCapturing(refactorArgs(fx));
        expect(exitCode, 0, reason: out);
        // The witness: the scoped re-proof names A1's own test (the
        // covering-test mapping the honesty gate rides).
        expect(out, contains('re-proof: scoped'), reason: out);
        expect(out, contains('test/a1_test.dart'), reason: out);

        final diskHash = await sha256Of(fx.subjectPathOf('A1'));
        final entries = await CycleEvidence(fx.featureDir).entries();
        final refreshes = entries
            .where((e) => e.behaviorId == 'A1' && e.kind == 'refresh')
            .toList();
        expect(refreshes, hasLength(1), reason: 'cycle log:\n$out');
        expect(refreshes.single.subjectHash, diskHash);
        expect(
          refreshes.single.at,
          isNotNull,
          reason: 'the freshness rule reads the refresh timestamp',
        );
      });
    },
  );

  group('issue #1430 — the honest guard stays honest (A-1430-3, U-1430-6)', () {
    test('A-1430-3: an out-of-band post-certification subject edit still '
        'refuses with the byte-identical #1036 diagnosis', () async {
      await seedCertifiedGreen(
        fx,
        id: 'A1',
        subjectContent: formattedSubject('A1'),
      );
      final certifiedHash = await sha256Of(fx.subjectPathOf('A1'));

      // Out-of-band drift: no refactor pass ran.
      await File(
        fx.subjectPathOf('A1'),
      ).writeAsString('${formattedSubject('A1')}\n// hand edit\n');
      final driftedHash = await sha256Of(fx.subjectPathOf('A1'));
      expect(driftedHash, isNot(certifiedHash));

      final out = await runner.runCapturing(makeArgs(fx, 'A1'));

      expect(exitCode, 1, reason: out);
      expect(out, contains('issue #1036'), reason: out);
      expect(
        out,
        contains('certified green evidence subject-hash'),
        reason: out,
      );
      expect(out, contains('current subject-hash'), reason: out);
      expect(out, contains('--re-certify'), reason: out);
    });

    test(
      'U-1430-6a: a refresh entry OLDER than the live green certification '
      'does not accept an out-of-band edit back to the refreshed shape',
      () async {
        // green(H1) at T_late; refresh(H2) at T_early (predates the live
        // green); the disk subject hand-set to H2 — the drift the refresh
        // once proved must still refuse, because the live certification
        // postdates it.
        await seedCertifiedGreen(
          fx,
          id: 'A1',
          subjectContent: malformedSubject('A1'),
          at: '2026-08-31T00:00:00.000Z',
        );
        final diskFile = File(fx.subjectPathOf('A1'));
        final refreshedShape = handImplementedSubject('A1');
        await diskFile.writeAsString(refreshedShape);
        await seedHashedEvidence(
          fx,
          id: 'A1',
          kind: 'refresh',
          subjectHash: await sha256Of(diskFile.path),
          at: '2026-08-29T00:00:00.000Z',
        );

        final out = await runner.runCapturing(makeArgs(fx, 'A1'));

        expect(exitCode, 1, reason: out);
        expect(out, contains('issue #1036'), reason: out);
      },
    );

    test('U-1430-6b: a refresh entry whose hash ≠ the current subject does '
        'not accept', () async {
      await seedCertifiedGreen(
        fx,
        id: 'A1',
        subjectContent: formattedSubject('A1'),
      );
      // A refresh proving some THIRD shape, newer than the green; the
      // disk subject drifted somewhere else entirely.
      await seedHashedEvidence(
        fx,
        id: 'A1',
        kind: 'refresh',
        subjectHash: crypto.sha256
            .convert(ascii.encode('third shape'))
            .toString(),
        at: '2026-08-31T00:00:00.000Z',
      );
      await File(
        fx.subjectPathOf('A1'),
      ).writeAsString('${formattedSubject('A1')}\n// hand edit\n');

      final out = await runner.runCapturing(makeArgs(fx, 'A1'));

      expect(exitCode, 1, reason: out);
      expect(out, contains('issue #1036'), reason: out);
    });

    test('U-1430-6c: the #1162 red-basis fail-open for hand-implemented '
        'subjects is unchanged (no refresh entry involved)', () async {
      // Certified RED on the throwing stub (records its hash); the
      // subject hand-implemented on disk; the target test passes.
      await fx.registerBehavior(
        id: 'A1',
        description: 'the A1 behavior',
        testContent: TddFixture.greenTest('the A1 behavior'),
      );
      final stub = File(fx.subjectPathOf('A1'));
      await stub.parent.create(recursive: true);
      await stub.writeAsString(throwingSubject('A1'));
      await seedHashedEvidence(
        fx,
        id: 'A1',
        kind: 'red',
        subjectHash: await sha256Of(stub.path),
      );
      await stub.writeAsString(handImplementedSubject('A1'));

      final out = await runner.runCapturing(makeArgs(fx, 'A1'));

      expect(exitCode, 0, reason: out);
      expect(out, contains('outcome=skipped'), reason: out);
      expect(out, contains('issue #1162'), reason: out);
    });

    test('U-1430-6d: the born-green placeholder refusal stands on a red-basis '
        'drift (the #1036 guard is not widened)', () async {
      await fx.registerBehavior(
        id: 'A1',
        description: 'the A1 behavior',
        testContent: TddFixture.greenTest('the A1 behavior'),
      );
      final stub = File(fx.subjectPathOf('A1'));
      await stub.parent.create(recursive: true);
      await stub.writeAsString(throwingSubject('A1'));
      await seedHashedEvidence(
        fx,
        id: 'A1',
        kind: 'red',
        subjectHash: await sha256Of(stub.path),
      );
      // Drifted to a DIFFERENT placeholder shape (the scaffolded marker).
      await stub.writeAsString(
        '// zfa:tdd: scaffolded — placeholder finders only\n'
        'library;\n\nvoid a1_value() {}\n',
      );

      final out = await runner.runCapturing(makeArgs(fx, 'A1'));

      expect(exitCode, 1, reason: out);
      expect(out, contains('issue #1036'), reason: out);
    });
  });

  group('issue #1430 — no green-washing, no surprise writes (U-1430-2..5)', () {
    test('U-1430-2: a misfired refactor (build pass fails) reconciles nothing '
        '— no refresh entry despite the rewrite', () async {
      await seedCertifiedGreen(
        fx,
        id: 'A1',
        subjectContent: malformedSubject('A1'),
      );
      // The build pass misfires (the fake scripts a non-driver failure).
      await fx.setStepOutcome('build', '', 'zfa build failed');

      final out = await runner.runCapturing(refactorArgs(fx));

      expect(exitCode, isNot(0), reason: out);
      final entries = await CycleEvidence(fx.featureDir).entries();
      expect(
        entries.where((e) => e.kind == 'refresh'),
        isEmpty,
        reason: 'a refused refactor is not a sanctioned refresh:\n$out',
      );
    });

    test('U-1430-3: a pass that touches no certified subject writes exactly '
        'today\'s evidence — the no-op refactor entry only', () async {
      await seedCertifiedGreen(
        fx,
        id: 'A1',
        subjectContent: formattedSubject('A1'),
      );
      final before = await File(fx.cycleLogPath).readAsString();

      final out = await runner.runCapturing(refactorArgs(fx));

      expect(out, contains('outcome=clean'), reason: out);
      expect(exitCode, 0, reason: out);
      expect(out, isNot(contains('forcing full re-proof')), reason: out);
      final entries = await CycleEvidence(fx.featureDir).entries();
      expect(entries.where((e) => e.kind == 'refresh'), isEmpty, reason: out);
      // The only appended section is the refactor no-op entry.
      final after = await File(fx.cycleLogPath).readAsString();
      final appended = after.substring(before.length);
      expect(appended, contains('- kind: refactor'), reason: appended);
      expect(appended, contains('- no-op: true'), reason: appended);
      expect(appended, isNot(contains('- kind: refresh')), reason: appended);
    });

    test(
      'U-1430-4: a not-certified behavior\'s rewritten subject lands no '
      'refresh entry (the next certify stamps the new shape naturally)',
      () async {
        // Registered and rewritten, but never certified: no green evidence.
        await seedCertifiedGreen(
          fx,
          id: 'A1',
          subjectContent: malformedSubject('A1'),
          certified: false,
        );

        final out = await runner.runCapturing(refactorArgs(fx));

        expect(out, contains('outcome=refactored'), reason: out);
        expect(exitCode, 0, reason: out);
        expect(out, isNot(contains('forcing full re-proof')), reason: out);
        final entries = await CycleEvidence(fx.featureDir).entries();
        expect(entries.where((e) => e.kind == 'refresh'), isEmpty, reason: out);
      },
    );

    test('U-1430-5: several certified subjects rewritten in one pass land one '
        'refresh entry per behavior', () async {
      await seedCertifiedGreen(
        fx,
        id: 'A1',
        subjectContent: malformedSubject('A1'),
      );
      await seedCertifiedGreen(
        fx,
        id: 'A2',
        subjectContent: malformedSubject('A2'),
      );

      final out = await runner.runCapturing(refactorArgs(fx));

      expect(exitCode, 0, reason: out);
      // The witness: the scoped re-proof covers both behaviors' own tests.
      expect(
        out,
        contains('re-proof: scoped (2 covering test(s)'),
        reason: out,
      );
      final entries = await CycleEvidence(fx.featureDir).entries();
      final refreshA1 = entries
          .where((e) => e.behaviorId == 'A1' && e.kind == 'refresh')
          .toList();
      final refreshA2 = entries
          .where((e) => e.behaviorId == 'A2' && e.kind == 'refresh')
          .toList();
      expect(refreshA1, hasLength(1), reason: out);
      expect(refreshA2, hasLength(1), reason: out);
      expect(
        refreshA1.single.subjectHash,
        await sha256Of(fx.subjectPathOf('A1')),
      );
      expect(
        refreshA2.single.subjectHash,
        await sha256Of(fx.subjectPathOf('A2')),
      );
    });
  });
}
