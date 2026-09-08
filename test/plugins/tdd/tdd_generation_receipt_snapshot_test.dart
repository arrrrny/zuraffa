/// Issue #1327 — TDD generation receipts keep small-text snapshots.
///
/// The proof checker's append-aware class (`cycle-log.md`) verifies a
/// post-receipt evidence append by prefix-checking the disk bytes
/// against the receipted bytes — which requires the receipt to HAVE the
/// receipted bytes. `TddGenerationReceipts` now applies the same
/// snapshot rule as the core capability writer: keep the content when
/// it is small text (at or below `ReceiptStore.maxSnapshotBytes` and
/// UTF-8 decodable), omit it otherwise.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/tdd_generation_receipt.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tdd_receipt_snapshot_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<GenerationReceiptFile?> entryFor(String name) async {
    final records = await ReceiptStore(projectRoot: tmp.path).loadAll();
    return records
        .expand((r) => r.receipt.files)
        .where((e) => e.path.endsWith(name))
        .firstOrNull;
  }

  test('a small text artifact keeps its content snapshot', () async {
    final file = File(p.join(tmp.path, 'specs', 'demo', 'tdd', 'cycle-log.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync('# Cycle log\n\n[make] U1 green\n');

    await TddGenerationReceipts.write(
      projectRoot: tmp.path,
      command: 'tdd make',
      target: 'U1',
      feature: 'demo',
      files: {file.path: 'update'},
    );

    final entry = await entryFor('cycle-log.md');
    expect(entry, isNotNull);
    expect(entry!.snapshot, '# Cycle log\n\n[make] U1 green\n');
  });

  test('an artifact above maxSnapshotBytes omits the snapshot', () async {
    final big = 'x' * (ReceiptStore.maxSnapshotBytes + 1);
    final file = File(p.join(tmp.path, 'specs', 'demo', 'tdd', 'notes.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync(big);

    await TddGenerationReceipts.write(
      projectRoot: tmp.path,
      command: 'tdd make',
      target: 'U1',
      feature: 'demo',
      files: {file.path: 'update'},
    );

    final entry = await entryFor('notes.md');
    expect(entry, isNotNull);
    expect(entry!.snapshot, isNull);
  });

  test('the append-only cycle-log keeps its snapshot at any size '
      '(the sanctioned-append check needs the receipted bytes)', () async {
    final big = 'x' * (ReceiptStore.maxSnapshotBytes + 1);
    final file = File(p.join(tmp.path, 'specs', 'demo', 'tdd', 'cycle-log.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync(big);

    await TddGenerationReceipts.write(
      projectRoot: tmp.path,
      command: 'tdd make',
      target: 'U1',
      feature: 'demo',
      files: {file.path: 'update'},
    );

    final entry = await entryFor('cycle-log.md');
    expect(entry, isNotNull);
    expect(entry!.snapshot, big);
  });

  test('binary bytes omit the snapshot', () async {
    final file = File(p.join(tmp.path, 'assets', 'mark.png'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([0x89, 0x50, 0x4e, 0x47, 0xff, 0xfe, 0x00, 0x01]);

    await TddGenerationReceipts.write(
      projectRoot: tmp.path,
      command: 'tdd make',
      target: 'U1',
      feature: 'demo',
      files: {file.path: 'create'},
    );

    final entry = await entryFor('mark.png');
    expect(entry, isNotNull);
    expect(entry!.snapshot, isNull);
  });
}
