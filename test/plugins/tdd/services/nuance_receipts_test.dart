// Fast unit tests for `NuanceReceipts` — the hand-delta provenance ledger
// (spec 913, T004: U14-U16).
//
//   U14: record() writes (file, reason, diff-hash) into
//        tdd/provenance-ledger.json (the #807 proof-carrying pattern).
//   U15: record() refuses an empty reason — reason metadata is enforced.
//   U16: detect() finds files whose bytes drifted from their last
//        receipted/ledger digest, and flags unreceipted files.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/nuance_receipts.dart';

void main() {
  late Directory temp;
  late String root;
  late String featureDir;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('nuance_');
    root = temp.path;
    featureDir = p.join(root, 'specs', '090-tdd-fixture');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  NuanceReceipts receipts() =>
      NuanceReceipts(featureDir: featureDir, projectRoot: root);

  Future<File> writeFile(String rel, String content) async {
    final file = File(p.join(root, rel));
    await file.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  test(
    'U14: record() writes (file, reason, diff-hash) into the ledger',
    () async {
      final file = await writeFile(
        'lib/src/data/datasources/user/user_mock_datasource.dart',
        'class UserMockDataSource {}',
      );
      final digest = crypto.sha256.convert(await file.readAsBytes()).toString();

      final entry = await receipts().record(
        file: 'lib/src/data/datasources/user/user_mock_datasource.dart',
        reason: 'tuned the injected latency for the search flow',
        adapter: 'UserRealAdapter',
      );

      expect(
        entry.file,
        'lib/src/data/datasources/user/user_mock_datasource.dart',
      );
      expect(entry.reason, 'tuned the injected latency for the search flow');
      expect(entry.diffHash, digest);
      expect(entry.adapter, 'UserRealAdapter');
      expect(entry.at, isNotEmpty);

      final ledgerFile = File(
        p.join(featureDir, 'tdd', 'provenance-ledger.json'),
      );
      expect(ledgerFile.existsSync(), isTrue);
      final ledger =
          jsonDecode(await ledgerFile.readAsString()) as Map<String, dynamic>;
      expect(ledger['schema'], 'realize-ledger.v1');
      expect(ledger['entries'], hasLength(1));
      expect(ledger['entries'].first['diffHash'], digest);
      expect(
        ledger['entries'].first['reason'],
        'tuned the injected latency for the search flow',
      );

      // Round-trip: load() reads the persisted entries back.
      final loaded = await receipts().load();
      expect(loaded, hasLength(1));
      expect(loaded.single.diffHash, digest);
    },
  );

  test('U15: record() refuses an empty reason — reason is enforced', () async {
    await writeFile('lib/src/di/x.dart', 'class X {}');

    expect(
      () => receipts().record(
        file: 'lib/src/di/x.dart',
        reason: '   ',
        adapter: 'UserRealAdapter',
      ),
      throwsA(
        isA<NuanceReceiptException>().having(
          (e) => e.message,
          'message',
          contains('reason'),
        ),
      ),
    );
    // Nothing was written.
    expect(
      File(p.join(featureDir, 'tdd', 'provenance-ledger.json')).existsSync(),
      isFalse,
    );
  });

  test('U16: detect() finds drifted and unreceipted hand-deltas', () async {
    const rel = 'lib/src/di/datasources/user_mock_datasource_di.dart';
    const original =
        'getIt.registerLazySingleton<UserMockDataSource>(() => '
        'UserMockDataSource());';
    final file = await writeFile(rel, original);

    // A #807 receipt covering the ORIGINAL bytes (the generation run).
    final store = ReceiptStore(projectRoot: root);
    await store.save(
      GenerationReceipt(
        command: 'zfa di',
        target: 'User',
        repro: 'zfa di User',
        at: DateTime.now().toUtc(),
        generatorVersion: '6.1.0',
        input: const {},
        files: [
          GenerationReceiptFile(
            path: rel,
            action: 'create',
            sha256: crypto.sha256.convert(original.codeUnits).toString(),
            bytes: original.length,
          ),
        ],
      ),
    );

    // Clean state: no drift yet.
    expect(await receipts().detect(files: [rel]), isEmpty);

    // Hand-edit the file: digest drift from the receipted baseline.
    await file.writeAsString('$original\n// hand-tuned');
    final drift = await receipts().detect(files: [rel]);
    expect(drift, hasLength(1));
    expect(drift.single.file, rel);
    expect(drift.single.detail, contains('drift'));
    expect(drift.single.actualHash, isNotEmpty);

    // Record the delta: detection is clean again (the ledger entry is the
    // new baseline).
    await receipts().record(
      file: rel,
      reason: 'hand-tuned for the demo fixture',
      adapter: 'UserRealAdapter',
    );
    expect(await receipts().detect(files: [rel]), isEmpty);

    // An unreceipted file (no baseline at all) is flagged too.
    await writeFile('lib/src/di/other.dart', 'class Other {}');
    final unreceipted = await receipts().detect(
      files: ['lib/src/di/other.dart'],
    );
    expect(unreceipted, hasLength(1));
    expect(unreceipted.single.detail, contains('no provenance'));

    // Exempt files are skipped.
    expect(
      await receipts().detect(
        files: ['lib/src/di/other.dart'],
        exempt: ['lib/src/di/other.dart'],
      ),
      isEmpty,
    );
  });
}
