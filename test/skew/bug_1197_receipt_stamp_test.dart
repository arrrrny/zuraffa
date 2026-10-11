import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/tdd_generation_receipt.dart';
import 'package:zuraffa/src/skew/skew_contract.dart';
import 'package:zuraffa/src/version.dart';

/// Issue #1197: the skew contract is STAMPED. Receipts already carry
/// `generator_version`; they must now also carry the declared core
/// floor (`min_core_version`) and the core the run actually generated
/// against (`generated_against_core`), so `zfa doctor` (and humans)
/// can diagnose a consumer left behind on an older core.
void main() {
  group('GenerationReceipt skew fields', () {
    test('round-trip min_core_version + generated_against_core', () {
      final at = DateTime.utc(2026, 9, 6);
      final receipt = GenerationReceipt(
        command: 'make',
        target: 'Todo',
        repro: 'zfa make Todo',
        at: at,
        generatorVersion: version,
        minCoreVersion: supportedCoreFloor,
        generatedAgainstCore: '6.0.1',
        input: const {},
        files: const [],
      );
      final json = receipt.toJson();
      expect(json['min_core_version'], supportedCoreFloor);
      expect(json['generated_against_core'], '6.0.1');

      final back = GenerationReceipt.fromJson(json);
      expect(back.minCoreVersion, supportedCoreFloor);
      expect(back.generatedAgainstCore, '6.0.1');
    });

    test('legacy receipts without the stamps still parse (back-compat)', () {
      final back = GenerationReceipt.fromJson({
        'schema': 'proof.v1',
        'command': 'make',
        'target': 'Todo',
        'repro': 'zfa make Todo',
        'at': '2026-01-01T00:00:00.000Z',
        'generator_version': '6.1.0',
        'input': {},
        'files': [],
      });
      expect(back.minCoreVersion, isNull);
      expect(back.generatedAgainstCore, isNull);
    });
  });

  group('TddGenerationReceipts stamping', () {
    late Directory temp;
    late File artifact;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('zfa1197_stamp_');
      artifact = File(path.join(temp.path, 'out.dart'))
        ..writeAsStringSync('// artifact\n');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('written receipts carry the generator version + core floor', () async {
      await TddGenerationReceipts.write(
        projectRoot: temp.path,
        command: 'zfa tdd gen',
        target: 'Todo',
        feature: 'f1197',
        files: {artifact.path: 'create'},
      );
      final dir = Directory(path.join(temp.path, '.zfa', 'receipts'));
      final receipts = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      expect(receipts, isNotEmpty);

      final json =
          jsonDecode(receipts.first.readAsStringSync()) as Map<String, dynamic>;
      // The de-hardcoding guard: the stamped version must track the
      // `version` const, so a future bump can never leave a stale
      // literal behind (the pre-1197 code hardcoded '6.1.0').
      expect(json['generator_version'], version);
      expect(json['min_core_version'], supportedCoreFloor);
    });
  });

  group('stamps bind the resolved core', () {
    test('SkewContract reports its generator version for stamping', () {
      final at = DateTime.utc(2026, 9, 6);
      final receipt = GenerationReceipt(
        command: 'make',
        target: 'Todo',
        repro: 'zfa make Todo',
        at: at,
        generatorVersion: version,
        minCoreVersion: supportedCoreFloor,
        generatedAgainstCore: null,
        input: const {},
        files: const [],
      );
      // generated_against_core is null when no core was resolvable —
      // the doctor treats that as 'unknown' (warn), never a false claim.
      expect(receipt.toJson().containsKey('generated_against_core'), isFalse);
    });
  });
}
