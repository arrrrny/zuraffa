// Bug #1429 — `zfa tdd reset` must roll back the phase-0 entity scaffolds.
//
// RED evidence: phase-0 (`tdd run`) scaffolds the entities the feature's
// test list declares under `### Key Entities` and ships an `entity create`
// receipt per scaffold into the global `.zfa/receipts/` store. The old
// reset only dropped the behavior-artifact registry + run-state — the
// entity scaffolds and their receipts survived, and after the inevitable
// hand-deletion of the scaffold files the surviving receipts poisoned the
// proof preflight with permanent `deleted` findings.
//
// These tests run in-process (CliRunner + TddFixture): reset spawns no
// subprocesses, so no `--json`-less AOT tier is needed. `--json` is passed
// explicitly so the machine verdict envelope is the final stdout line.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-bug-1429';
  const declaredEntity = 'PlatformException';
  const declaredSnake = 'platform_exception';
  // A scaffold another feature (or hand-written code) owns — NOT declared
  // by this feature's test list. Reset must never touch it.
  const foreignEntity = 'Keeper';
  const foreignSnake = 'keeper';

  String rootPath() => fx.root.path;

  Directory entityDir(String snake) =>
      Directory(p.join(rootPath(), 'lib', 'src', 'domain', 'entities', snake));

  String entityRelPath(String snake) =>
      'lib/src/domain/entities/$snake/$snake.dart';

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', ...args, '--project', fx.root.path]);
  }

  /// The last non-empty stdout line — the `--json` verdict contract.
  Map<String, dynamic> verdict(String out) {
    final lines = out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return jsonDecode(lines.last) as Map<String, dynamic>;
  }

  /// Append the `## Key entities` section phase-0 reads
  /// (TestListReader.readEntities — the same source the reset rollback
  /// consults).
  Future<void> declareEntities(List<(String, String)> rows) async {
    final file = File(fx.testListPath);
    final buf = StringBuffer(file.existsSync() ? file.readAsStringSync() : '')
      ..writeln()
      ..writeln('## Key entities')
      ..writeln()
      ..writeln('| entity | fields |')
      ..writeln('| ------ | ------ |');
    for (final (name, fields) in rows) {
      buf.writeln('| $name | $fields |');
    }
    buf.writeln();
    await file.writeAsString(buf.toString());
  }

  /// Materialize a phase-0-shaped entity scaffold (the canonical
  /// `<entities>/<snake>/<snake>.dart` layout) and ship the matching
  /// `entity create` receipt.
  Future<void> seedPhaseZeroScaffold(
    String name,
    String snake, {
    ReceiptStore? store,
  }) async {
    final dir = entityDir(snake);
    await dir.create(recursive: true);
    await File(
      p.join(dir.path, '$snake.dart'),
    ).writeAsString('// entity $name (phase-0 scaffold)\n');
    await (store ?? ReceiptStore(projectRoot: fx.root.path)).save(
      GenerationReceipt(
        command: 'entity create',
        target: name,
        repro: 'zfa entity create -n $name',
        at: DateTime.now().toUtc(),
        generatorVersion: 'test',
        input: const <String, dynamic>{},
        files: [
          GenerationReceiptFile(
            path: entityRelPath(snake),
            action: 'create',
            sha256: 'deadbeef$snake',
            bytes: 0,
          ),
        ],
        plugin: 'entity',
        capability: 'create',
        entity: name,
        methodset: const <String>[],
        receiptVersion: 1,
      ),
    );
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('bug 1429 — reset reverts phase-0 entity scaffolds', () {
    test(
      'A1: reset deletes the declared scaffold dir, prunes its entity '
      'receipts, keeps foreign entities, and reports both in the verdict',
      () async {
        await declareEntities([(declaredEntity, 'code:String')]);
        final store = ReceiptStore(projectRoot: fx.root.path);
        await seedPhaseZeroScaffold(declaredEntity, declaredSnake);
        // Foreign: exists on disk + receipted, but NOT declared by the
        // feature's test list — never reset's business.
        await seedPhaseZeroScaffold(foreignEntity, foreignSnake, store: store);

        final out = await runCli(['reset', feature, '--json']);

        expect(exitCode, 0, reason: out);
        // Declared scaffold reverted (files AND directory).
        expect(entityDir(declaredSnake).existsSync(), isFalse, reason: out);
        // Declared entity's receipts pruned.
        final remaining = await store.loadAll();
        expect(
          remaining
              .where((r) => r.receipt.entity == declaredEntity)
              .map((r) => r.fileName),
          isEmpty,
          reason: out,
        );
        // Foreign scaffold + receipt untouched.
        expect(entityDir(foreignSnake).existsSync(), isTrue, reason: out);
        expect(
          remaining.where((r) => r.receipt.entity == foreignEntity),
          hasLength(1),
          reason: out,
        );
        // Verdict reports the rollback (the envelope's top-level verdict
        // is the OUTCOME; the command's own label lives in details).
        final v = verdict(out);
        expect(v['exit_class'], 'ok');
        expect((v['details'] as Map)['verdict'], 'reset');
        expect(
          ((v['details'] as Map)['reverted_entities'] as List).join(' '),
          contains(declaredEntity),
        );
        expect(
          ((v['details'] as Map)['pruned_receipts'] as List),
          hasLength(1),
          reason: out,
        );
      },
    );

    test(
      'A2: reset heals the hand-deleted-scaffold state — receipt pruned, '
      'proof check green afterwards (the issue\'s poisoned preflight)',
      () async {
        await declareEntities([(declaredEntity, 'code:String')]);
        // The issue's intermediate state: the author hand-deleted the
        // scaffold, the entity_create receipt survived, and every proof
        // check reports `deleted` forever.
        await seedPhaseZeroScaffold(declaredEntity, declaredSnake);
        await entityDir(declaredSnake).delete(recursive: true);
        final poisoned = await ProofChecker(projectRoot: fx.root.path).check();
        expect(poisoned.ok, isFalse, reason: 'baseline must be poisoned');
        expect(
          poisoned.findings
              .where((f) => f.kind == ProofFinding.kindDeleted)
              .toList(),
          isNotEmpty,
        );

        final out = await runCli(['reset', feature, '--json']);

        expect(exitCode, 0, reason: out);
        final healed = await ProofChecker(projectRoot: fx.root.path).check();
        expect(
          healed.ok,
          isTrue,
          reason: healed.findings.map((f) => f.detail).join('\n'),
        );
      },
    );

    test('A3: reset with no declared entities prunes nothing (legacy verdict '
        'shape preserved)', () async {
      final store = ReceiptStore(projectRoot: fx.root.path);
      await seedPhaseZeroScaffold(foreignEntity, foreignSnake, store: store);

      final out = await runCli(['reset', feature, '--json']);

      expect(exitCode, 0, reason: out);
      final v = verdict(out);
      expect((v['details'] as Map)['verdict'], 'reset');
      expect(
        (v['details'] as Map).containsKey('reverted_entities'),
        isFalse,
        reason: out,
      );
      expect(
        (v['details'] as Map).containsKey('pruned_receipts'),
        isFalse,
        reason: out,
      );
      // The undeclared entity is untouched.
      expect(entityDir(foreignSnake).existsSync(), isTrue, reason: out);
      expect(await store.loadAll(), hasLength(1), reason: out);
    });
  });
}
