// Issue #1423 — the proof preflight refuses the DESIGNED hand-delta.
//
// `zfa tdd run` stops at `<id>:hand` and prescribes: hand-write assertions,
// hand-implement the subject, certify. The gen receipt recorded the test/
// subject digests at GEN TIME; the certification transitions that close the
// hand-delta (`verify-red --re-certify`, make's #694 skip) receipt ONLY
// `tdd/cycle-log.md` — so `ProofChecker`'s latest-wins still resolves the
// pre-hand-delta gen bytes and `zfa tdd verify` refuses:
//
//   digest mismatch: receipt says c4df44b3dd5, disk has 0c8825e43b92
//   (action: create)  →  NOT_ASSESSED, exit 3
//
// Verify is UNREACHABLE for hand-delta'd features and the prescribed remedy
// (`zfa tdd gen`) destroys the certified work (the #1375 class).
//
// Contract pinned here (remediation, spec 1423):
//   E1  (SC-2) `verify-red --re-certify` appends the hand-delta receipt:
//       the drifted receipted test/subject paths re-hashed from CURRENT
//       disk bytes, action `update`, feature-scoped, sanctioned+hand_delta
//       markers, transition `re-certify` (the #1311 refactor-refresh
//       pattern for the hand-delta class);
//   E2  (SC-1) make's skip transition performs the same re-receipt
//       (transition `skip`); the plain red-certification path does NOT;
//   E3  (SC-3) the full hand-delta flow reaches `zfa tdd verify`'s mutation
//       audit — no `failed the proof preflight` refusal;
//   E4  a skip over an UNCHANGED pair appends NO hand-delta receipt (the
//       gen receipts still validate — backward compatibility);
//   E5  (SC-4) doctor does NOT report `stores agree` while hand-delta
//       drift exists: drift line naming behavior+path, prescribes the
//       re-certify transition, never `zfa tdd gen`;
//   E6  (SC-4 converse) after the sanctioned transitions complete, doctor
//       reports `stores agree` again.
//
// RED evidence (pre-fix master): E1/E2/E3/E5 fail — no `hand_delta` receipt
// exists, ProofChecker still reports `modified` on the hand-edited pair,
// verify refuses with the proof-preflight refusal, doctor prints `stores
// agree`. E4/E6 pass pre-fix and pin the backward-compatibility line.
//
// Slow tier: spawns real `dart test` subprocesses in throwaway TddFixture
// projects (the bug #1162 convention).
@Tags(['slow'])
library;

import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

import 'helpers/tdd_fixture.dart';

/// The gen-shaped THROWING subject stub (`zfa tdd gen <id>`): the fixture
/// convention declares `<snake>_value` (the symbol the paired tests call).
String throwingSubject1423(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
// GENERATED STUB — `zfa tdd gen $id`.
library;

/// Scenario runner for behavior $id.
///
/// Throws [UnimplementedError] until the real implementation lands.
int $symbol() => throw UnimplementedError('$symbol not implemented');
''';
}

/// A HAND IMPLEMENTATION (the #1423 sanctioned state): real logic, not a
/// pipeline scaffold shape — computes the answer from parts.
String handImplementedSubject1423(String id) {
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

/// A subject-driven test that fails on the stub and passes on the real
/// implementation (the honest red -> green pair) — the GEN shape: the
/// subject call is wrapped so the failure is an authored expect mismatch
/// (an assertion), never an uncaught error (spec 046's honest-red rule).
String subjectDrivenTest1423(String id, String description) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    final Object? result = (() {
      try {
        return $symbol();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, equals(42));
  });
}
''';
}

/// A HAND-WRITTEN assertion delta in the generated test (the designed
/// `<id>:hand` edit): the same honest red -> green pair with a hand-added
/// annotation comment — ANY byte change drifts the gen receipt.
String handEditedTest1423(String id, String description) =>
    subjectDrivenTest1423(id, description).replaceFirst(
      'void main() {',
      '// Hand-written assertions (the designed <id>:hand step, issue #1308).\n'
      'void main() {',
    );

/// Seed the gen-style proof receipts for [id]'s test + subject pair: one
/// proof.v1 document (command `tdd gen`, feature-scoped) binding the
/// CURRENT on-disk bytes — exactly what `zfa tdd gen` writes at gen time.
Future<void> seedGenReceipts1423(TddFixture fx, String id) async {
  final files = <GenerationReceiptFile>[];
  for (final path in [fx.testPathOf(id), fx.subjectPathOf(id)]) {
    final bytes = await File(path).readAsBytes();
    files.add(
      GenerationReceiptFile(
        path: p.relative(path, from: fx.root.path).replaceAll(r'\', '/'),
        action: 'create',
        sha256: crypto.sha256.convert(bytes).toString(),
        bytes: bytes.length,
      ),
    );
  }
  await ReceiptStore(projectRoot: fx.root.path).save(
    GenerationReceipt(
      command: 'tdd gen',
      target: id,
      repro: 'zfa tdd gen $id',
      at: DateTime.now().toUtc(),
      generatorVersion: 'tdd-fixture',
      input: {'feature': fx.featureName},
      files: files,
    ),
  );
}

/// Every appended receipt carrying the sanctioned hand-delta markers.
Future<List<ReceiptRecord>> handDeltaReceiptsOf(TddFixture fx) async =>
    (await ReceiptStore(projectRoot: fx.root.path).loadAll())
        .where((r) => r.receipt.input['hand_delta'] == true)
        .toList();

/// The latest-wins receipt digest for a project-relative path (the same
/// resolution `ProofChecker` applies), or null when nothing covers it.
Future<String?> latestReceiptDigestOf(TddFixture fx, String relPath) async {
  String? latest;
  for (final record
      in await ReceiptStore(projectRoot: fx.root.path).loadAll()) {
    for (final entry in record.receipt.files) {
      if (entry.path == relPath) latest = entry.sha256;
    }
  }
  return latest;
}

String diskDigestOf(TddFixture fx, String relPath) => crypto.sha256
    .convert(File(p.join(fx.root.path, relPath)).readAsBytesSync())
    .toString();

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });
  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('issue #1423 — verify-red --re-certify re-receipts the hand-delta', () {
    test(
      'E1: the drifted receipted subject is re-hashed (action update, '
      'current digest) and the hand-delta state proves clean',
      () async {
        const desc = 'returns 42 when invoked with no args';
        const id = 'A1';
        await fx.seedCertifiedRed(
          id: id,
          description: desc,
          testContent: subjectDrivenTest1423(id, desc),
          subjectContent: throwingSubject1423(id),
        );
        await seedGenReceipts1423(fx, id);
        final runner = CliRunner(exitOnCompletion: false);

        // The designed hand step: hand-implement the subject (what the
        // gen'd test header instructs). The test now genuinely passes.
        await File(
          fx.subjectPathOf(id),
        ).writeAsString(handImplementedSubject1423(id));

        final out = await runner.runCapturing([
          'tdd',
          'verify-red',
          '--project',
          fx.root.path,
          '--re-certify',
          id,
        ]);
        expect(exitCode, 0, reason: out);
        expect(out, contains('classification=re-certified'));

        // SC-2: ONE appended hand-delta receipt covering the drifted
        // subject path with the CURRENT digest (never the old gen digest).
        final events = await handDeltaReceiptsOf(fx);
        expect(
          events,
          hasLength(1),
          reason: 'exactly one hand-delta receipt must be appended:\n$out',
        );
        final event = events.single.receipt;
        expect(event.schema, 'proof.v1');
        expect(event.command, 'tdd verify-red --re-certify');
        expect(event.input['feature'], fx.featureName);
        expect(event.input['sanctioned'], true);
        expect(event.input['hand_delta'], true);
        expect(event.input['transition'], 're-certify');
        expect(event.input['behavior'], id);
        final subjectRel = p
            .relative(fx.subjectPathOf(id), from: fx.root.path)
            .replaceAll(r'\', '/');
        final entry = event.files.singleWhere((f) => f.path == subjectRel);
        expect(entry.action, 'update');
        expect(
          entry.sha256,
          diskDigestOf(fx, subjectRel),
          reason: 'digest must be re-derived from the hand-implemented bytes',
        );
        expect(
          await latestReceiptDigestOf(fx, subjectRel),
          diskDigestOf(fx, subjectRel),
          reason: 'latest-wins must resolve to the certified hand-delta',
        );

        // The original gen receipt stays (append-only provenance).
        final all = await ReceiptStore(projectRoot: fx.root.path).loadAll();
        expect(
          all.where((r) => r.receipt.command == 'tdd gen'),
          hasLength(1),
        );

        // The checker level: zero `modified` findings for the pair.
        final report = await ProofChecker(projectRoot: fx.root.path).check();
        expect(
          report.findings.where((f) => f.kind == ProofFinding.kindModified),
          isEmpty,
          reason:
              'the re-receipt must resolve the hand-delta drift; findings: '
              '${report.findings.map((f) => f.toJson())}',
        );

        // The follow-up make skips cleanly (the #1162 contract holds).
        final makeOut = await runner.runCapturing([
          'tdd',
          'make',
          '--project',
          fx.root.path,
          id,
        ]);
        expect(exitCode, 0, reason: makeOut);
        expect(makeOut, contains('outcome=skipped'));
      },
    );
  });

  group('issue #1423 — make skip re-receipts the hand-delta', () {
    test(
      'E2: the skip transition re-hashes the drifted receipted pair; the '
      'plain red path does not (SC-1 + red-path backward compat)',
      () async {
        const desc = 'returns 42 when invoked with no args';
        const id = 'A2';
        const redId = 'U2';
        await fx.seedCertifiedRed(
          id: id,
          description: desc,
          testContent: subjectDrivenTest1423(id, desc),
          subjectContent: throwingSubject1423(id),
        );
        await seedGenReceipts1423(fx, id);
        await fx.seedCertifiedRed(
          id: redId,
          description: desc,
          testContent: subjectDrivenTest1423(redId, desc),
          subjectContent: throwingSubject1423(redId),
        );
        await seedGenReceipts1423(fx, redId);
        final runner = CliRunner(exitOnCompletion: false);

        // The red path first (plain verify-red against the throwing stub):
        // an honest assertion red — NO hand-delta receipt may fire here.
        final redOut = await runner.runCapturing([
          'tdd',
          'verify-red',
          '--project',
          fx.root.path,
          redId,
        ]);
        expect(exitCode, 0, reason: redOut);
        expect(
          await handDeltaReceiptsOf(fx),
          isEmpty,
          reason: 'the red certification is not a hand-delta transition',
        );

        // The designed hand step: hand-implement the subject. Now make's
        // skip transition closes the cycle (the #1162 fail-open).
        await File(
          fx.subjectPathOf(id),
        ).writeAsString(handImplementedSubject1423(id));

        final out = await runner.runCapturing([
          'tdd',
          'make',
          '--project',
          fx.root.path,
          id,
        ]);
        expect(exitCode, 0, reason: out);
        expect(out, contains('outcome=skipped'));

        // SC-1: ONE appended hand-delta receipt, transition `skip`.
        final events = await handDeltaReceiptsOf(fx);
        expect(events, hasLength(1), reason: 'make output:\n$out');
        final event = events.single.receipt;
        expect(event.schema, 'proof.v1');
        expect(event.command, 'tdd make');
        expect(event.input['feature'], fx.featureName);
        expect(event.input['sanctioned'], true);
        expect(event.input['hand_delta'], true);
        expect(event.input['transition'], 'skip');
        expect(event.input['behavior'], id);
        final subjectRel = p
            .relative(fx.subjectPathOf(id), from: fx.root.path)
            .replaceAll(r'\', '/');
        final entry = event.files.singleWhere((f) => f.path == subjectRel);
        expect(entry.action, 'update');
        expect(entry.sha256, diskDigestOf(fx, subjectRel));

        // The gen receipts stay; the checker resolves zero `modified`.
        final all = await ReceiptStore(projectRoot: fx.root.path).loadAll();
        expect(all.where((r) => r.receipt.command == 'tdd gen'), hasLength(2));
        final report = await ProofChecker(projectRoot: fx.root.path).check();
        expect(
          report.findings.where((f) => f.kind == ProofFinding.kindModified),
          isEmpty,
          reason:
              'findings: ${report.findings.map((f) => f.toJson())}',
        );
      },
    );

    test(
      'E4: a skip over an UNCHANGED pair appends NO hand-delta receipt — '
      'the gen receipts still validate (backward compatibility)',
      () async {
        const desc = 'returns 42 when invoked with no args';
        const id = 'A4';
        await fx.seedCertifiedRed(
          id: id,
          description: desc,
          testContent: subjectDrivenTest1423(id, desc),
          // The subject ALREADY satisfies the test (no hand step happened —
          // the drift re-run passes, the skip transition closes it).
          subjectContent: '''
library;

int ${id.toLowerCase().replaceAll('-', '_')}_value() => 42;
''',
        );
        await seedGenReceipts1423(fx, id);
        final runner = CliRunner(exitOnCompletion: false);

        final out = await runner.runCapturing([
          'tdd',
          'make',
          '--project',
          fx.root.path,
          id,
        ]);
        expect(exitCode, 0, reason: out);
        expect(out, contains('outcome=skipped'));

        expect(
          await handDeltaReceiptsOf(fx),
          isEmpty,
          reason: 'no drift — nothing to re-receipt (idempotent no-op):\n$out',
        );
        final report = await ProofChecker(projectRoot: fx.root.path).check();
        expect(report.findings, isEmpty, reason: out);
      },
    );
  });

  group('issue #1423 — verify is reachable for a hand-delta\u00b7d feature', () {
    test(
      'E3: gen receipts -> hand edits -> re-certify -> make skip -> '
      '`zfa tdd verify` reaches the mutation audit (SC-3)',
      () async {
        const desc = 'returns 42 when invoked with no args';
        const id = 'A3';
        await fx.seedCertifiedRed(
          id: id,
          description: desc,
          testContent: subjectDrivenTest1423(id, desc),
          subjectContent: throwingSubject1423(id),
        );
        await seedGenReceipts1423(fx, id);
        final runner = CliRunner(exitOnCompletion: false);

        // The designed hand step: hand-written assertions AND the
        // hand-implemented subject — BOTH receipted artifacts drift.
        await File(
          fx.testPathOf(id),
        ).writeAsString(handEditedTest1423(id, desc));
        await File(
          fx.subjectPathOf(id),
        ).writeAsString(handImplementedSubject1423(id));

        // Sanity (the bug): the checker sees the drift the transitions
        // must heal.
        final before = await ProofChecker(projectRoot: fx.root.path).check();
        expect(
          before.findings.where((f) => f.kind == ProofFinding.kindModified),
          hasLength(2),
          reason: 'both hand-edited artifacts must drift pre-certification',
        );

        final recert = await runner.runCapturing([
          'tdd',
          'verify-red',
          '--project',
          fx.root.path,
          '--re-certify',
          id,
        ]);
        expect(exitCode, 0, reason: recert);

        final makeOut = await runner.runCapturing([
          'tdd',
          'make',
          '--project',
          fx.root.path,
          id,
        ]);
        expect(exitCode, 0, reason: makeOut);
        expect(makeOut, contains('outcome=skipped'));

        // SC-3: the proof preflight validates the certified hand-delta —
        // the mutation audit phase is reached, never the NOT_ASSESSED
        // refusal. Pre-fix this fails with `failed the proof preflight`.
        final out = await runner.runCapturing([
          'tdd',
          'verify',
          '--feature',
          fx.featureName,
          '--project',
          fx.root.path,
        ]);
        expect(
          out,
          isNot(contains('failed the proof preflight')),
          reason: 'the certified hand-delta must pass the proof preflight:\n'
              '$out',
        );
        expect(
          out,
          contains('running mutation audit'),
          reason: 'the preflight must let the audit run:\n$out',
        );
      },
    );
  });

  group('issue #1423 — doctor does not call a drifted hand-delta healthy', () {
    test(
      'E5: hand-delta drift present -> no `stores agree`, drift line names '
      'behavior+path, prescription is the re-certify transition (SC-4)',
      () async {
        const desc = 'returns 42 when invoked with no args';
        const id = 'A5';
        await fx.seedCertifiedRed(
          id: id,
          description: desc,
          testContent: subjectDrivenTest1423(id, desc),
          subjectContent: throwingSubject1423(id),
        );
        await seedGenReceipts1423(fx, id);

        // The hand-delta happened; the certification transitions have NOT
        // run yet — exactly the state the `<id>:hand` stop leaves.
        await File(
          fx.subjectPathOf(id),
        ).writeAsString(handImplementedSubject1423(id));

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'doctor',
          fx.featureName,
          '--project',
          fx.root.path,
        ]);
        expect(
          exitCode,
          isNot(0),
          reason: 'a drifted hand-delta must not read healthy:\n$out',
        );
        expect(
          out,
          isNot(contains('stores agree')),
          reason: 'SC-4: doctor must not claim the stores agree:\n$out',
        );
        expect(out, contains('hand-delta drift'));
        expect(out, contains(id));
        final subjectRel = p
            .relative(fx.subjectPathOf(id), from: fx.root.path)
            .replaceAll(r'\', '/');
        expect(out, contains(subjectRel));
        expect(
          out,
          contains('--re-certify'),
          reason: 'the sanctioned transition must be prescribed:\n$out',
        );
        expect(
          out,
          isNot(contains('zfa tdd gen')),
          reason: 'the destructive remedy (#1375) must never be prescribed:\n'
              '$out',
        );
      },
    );

    test(
      'E6: after the sanctioned transitions complete -> doctor reports '
      '`stores agree` again (SC-4 converse)',
      () async {
        const desc = 'returns 42 when invoked with no args';
        const id = 'A6';
        await fx.seedCertifiedRed(
          id: id,
          description: desc,
          testContent: subjectDrivenTest1423(id, desc),
          subjectContent: throwingSubject1423(id),
        );
        await seedGenReceipts1423(fx, id);
        final runner = CliRunner(exitOnCompletion: false);

        await File(
          fx.subjectPathOf(id),
        ).writeAsString(handImplementedSubject1423(id));

        final recert = await runner.runCapturing([
          'tdd',
          'verify-red',
          '--project',
          fx.root.path,
          '--re-certify',
          id,
        ]);
        expect(exitCode, 0, reason: recert);
        final makeOut = await runner.runCapturing([
          'tdd',
          'make',
          '--project',
          fx.root.path,
          id,
        ]);
        expect(exitCode, 0, reason: makeOut);

        final out = await runner.runCapturing([
          'tdd',
          'doctor',
          fx.featureName,
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 0, reason: 'the healed state must read healthy:\n$out');
        expect(out, contains('stores agree'));
      },
    );
  });
}
