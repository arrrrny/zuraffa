// U7-U11 (spec 070): the golden workflow — setup → corpus verify →
// per-feature gates → gap ledger + coverage matrix (FR-001), idempotent
// and resumable with partial results preserved on interruption
// (FR-010, SC-006).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/golden_workflow.dart';

void main() {
  late Directory root;
  late GoldenWorkflow workflow;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('golden_');
    workflow = GoldenWorkflow(root.path);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<String> writeFile(String rel, String content) async {
    final file = File(p.join(root.path, rel));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return rel;
  }

  Future<void> writeFeature({
    required String feature,
    required String subject,
    bool green = true,
    bool simulated = false,
  }) async {
    await writeFile(
      'specs/$feature/tdd/artifacts.json',
      jsonEncode({
        'records': [
          {
            'behavior_id': 'B-001',
            'feature': feature,
            'source_criterion': 'FR-001',
            'test_path': 'test/${feature}_test.dart',
            'subject_path': subject,
            'runnable_test_name': 'file::B-001::does it',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-09-01T00:00:00Z',
          },
        ],
      }),
    );
    final content = 'class S {}\n';
    await writeFile(subject, content);
    if (green) {
      await writeFile(
        'specs/$feature/tdd/cycle-log.md',
        '## Cycle: B-001 (green)\n\n- behavior: B-001\n- kind: green\n',
      );
    }
    if (simulated) {
      await writeFile(
        'specs/$feature/tdd/fixtures/manifest.json',
        jsonEncode({
          'families': ['rest'],
          'digest': 'x',
          'files': [],
        }),
      );
    }
    final store = ReceiptStore(projectRoot: root.path);
    await store.save(
      GenerationReceipt(
        command: 'tdd-gen',
        target: feature,
        repro: 'zfa tdd gen',
        at: DateTime.utc(2026, 9, 2),
        generatorVersion: '6.1.0',
        input: const {},
        files: [
          GenerationReceiptFile(
            path: subject,
            action: 'create',
            sha256: sha256.convert(content.codeUnits).toString(),
            bytes: content.length,
          ),
        ],
      ),
    );
  }

  test('U7: executes setup → corpus verify → per-feature gates → outputs, '
      'and is idempotent (FR-001)', () async {
    await writeFeature(feature: 'f-a', subject: 'lib/a.dart');
    await writeFeature(feature: 'f-b', subject: 'lib/b.dart');

    final verdict = await workflow.run();

    // Every step ran, in order.
    expect(
      verdict.steps,
      containsAll(['setup', 'corpus-verify', 'per-feature-gates', 'outputs']),
    );
    expect(verdict.steps.first, 'setup');
    expect(verdict.steps.last, 'outputs');
    expect(verdict.features, hasLength(2));

    // Idempotent: a second run on the same state produces the same
    // verdict (assumption: golden workflow is idempotent).
    final verdict2 = await workflow.run();
    expect(verdict2.result, verdict.result);
    expect(
      verdict2.features.map((f) => f.feature).toList(),
      verdict.features.map((f) => f.feature).toList(),
    );
    expect(verdict2.steps, verdict.steps);
  });

  test('U8: partial results are preserved on interruption and the next run '
      'resumes from the last completed step (FR-010, SC-006)', () async {
    await writeFeature(feature: 'f-a', subject: 'lib/a.dart');

    // Simulate an interruption after `corpus-verify`: the run-state
    // file records the completed steps and the partial results.
    final runStatePath = p.join(
      root.path,
      '.zfa',
      'corpus',
      'referee-run.json',
    );
    await File(runStatePath).parent.create(recursive: true);
    await File(runStatePath).writeAsString(
      jsonEncode({
        'completed_steps': ['setup', 'corpus-verify'],
        'result': 'partial',
        'features': [
          {
            'feature': 'f-a',
            'state': 'complete(real)',
            'receipts': 1,
            'hand_delta_receipts': 0,
            'buckets': {
              'generated': 1,
              'mock': 0,
              'hand_delta': 0,
              'hand_written': 0,
            },
            'receipt_verified': true,
            'receipt_ids': ['r-a'],
          },
        ],
      }),
    );

    final verdict = await workflow.run(resume: true);

    // Resumed: the completed steps were not re-run (the run-state was
    // loaded, extended, and the verdict completed).
    expect(verdict.resumedFrom, isNotNull);
    expect(verdict.resumedFrom, contains('corpus-verify'));
    expect(verdict.steps, contains('per-feature-gates'));
    expect(
      verdict.steps,
      isNot(contains('setup')),
      reason: 'setup already completed — not repeated',
    );
    // The partial feature result survived into the final verdict.
    expect(verdict.features.map((f) => f.feature), contains('f-a'));
  });

  test('U9: the gap ledger summary lists features not at their target state '
      '(FR-013)', () async {
    await writeFeature(feature: 'f-real', subject: 'lib/real.dart');
    await writeFeature(
      feature: 'f-mock',
      subject: 'lib/mock.dart',
      simulated: true,
    );
    // A gap ledger with an open, blocking gap on f-mock.
    await File(
      p.join(root.path, '.zfa', 'corpus', 'gap-ledger.json'),
    ).parent.create(recursive: true);
    await File(
      p.join(root.path, '.zfa', 'corpus', 'gap-ledger.json'),
    ).writeAsString(
      jsonEncode([
        {
          'id': 'gap-001',
          'kind': 'gap',
          'at': '2026-09-03T00:00:00Z',
          'feature': 'f-mock',
          'step': 'verify',
          'outcome': 'not_assessed',
          'expected_result': 'pass',
          'status': 'open',
        },
      ]),
    );

    final verdict = await workflow.run();
    expect(verdict.gapLedger.found, 1);
    expect(verdict.gapLedger.open, 1);
    expect(verdict.gapLedger.blocking, contains('f-mock'));
    // f-real is at target (real); f-mock is not — named in the ledger
    // summary.
    expect(verdict.gapLedger.blocking, isNot(contains('f-real')));
  });

  test('U10: the coverage matrix tracks features against test tiers from '
      'recorded evidence (FR-014)', () async {
    // f-real: unit tier evidence (a green cycle-log entry) + mutation
    // evidence (a mutation report file).
    await writeFeature(feature: 'f-real', subject: 'lib/real.dart');
    await writeFile(
      'specs/f-real/tdd/mutation-report.json',
      jsonEncode({'mutation_score': 0.92, 'gate': 'pass'}),
    );
    await writeFeature(
      feature: 'f-mock',
      subject: 'lib/mock.dart',
      simulated: true,
    );

    final verdict = await workflow.run();
    final matrix = verdict.coverage;
    expect(matrix.rows, hasLength(2));
    final realRow = matrix.rows.firstWhere((r) => r.feature == 'f-real');
    expect(realRow.tiers, contains('unit'));
    expect(realRow.tiers, contains('mutation'));
    final mockRow = matrix.rows.firstWhere((r) => r.feature == 'f-mock');
    expect(mockRow.tiers, contains('unit'));
    expect(mockRow.tiers, isNot(contains('mutation')));
  });

  test('U11: an empty corpus with no receipts shows the empty state, never '
      'crashes (edge case)', () async {
    final verdict = await workflow.run();
    expect(verdict.result, 'empty');
    expect(verdict.features, isEmpty);
    expect(verdict.steps, contains('outputs'));
  });
}
