// EPIC 1150 — zuraffa.verdict.v1: the canonical --json envelope for the
// whole fleet (unit layer).
//
// RED evidence (recorded 2026-09-07, commit e5b5cc68): the fleet shipped 8
// divergent --json shapes with no single parser an agent can rely on:
//
//   1. zfa xray status --json        -> {"enabled":bool,"release_mode":bool}
//   2. zfa tdd verdicts --json       -> verdict.v1 (verdict/details/timestamp)
//   3. zfa manifest (json default)   -> bare JSON ARRAY of tools
//   4. zfa manifest --verify --json  -> manifest-verify.v1
//   5. zfa proof check --format=json -> proof.v1
//   6. zfa doctor --format=json      -> doctor.v1
//   7. zfa benchmark list --json     -> {"scenarios":[]}
//   8. zfa make --format=json        -> {"success":bool, plan, files, ...}
//
// This file pins the canonical envelope TYPE and its JSON contract.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/verdict/verdict_envelope.dart';

void main() {
  group('VerdictEnvelope (zuraffa.verdict.v1)', () {
    test('schema constant is exactly "zuraffa.verdict.v1"', () {
      expect(VerdictEnvelope.schema, 'zuraffa.verdict.v1');
    });

    test('result enum covers ok | error | skipped | refused', () {
      expect(
        VerdictResult.values.map((r) => r.name).toSet(),
        {'ok', 'error', 'skipped', 'refused'},
      );
    });

    test('toJson carries every mandated key with the mandated types', () {
      final envelope = VerdictEnvelope(
        command: 'zfa xray status',
        result: VerdictResult.ok,
        message: 'xray overlay is disabled',
        data: {'enabled': false, 'release_mode': false},
        timestamp: DateTime.utc(2026, 9, 5, 18, 30),
      );

      final json = envelope.toJson();
      expect(json['schema'], 'zuraffa.verdict.v1');
      expect(json['command'], 'zfa xray status');
      expect(json['result'], 'ok');
      expect(json['exit_class'], 0, reason: 'exit_class is the int exit code');
      expect(json['message'], 'xray overlay is disabled');
      expect(json['data'], {'enabled': false, 'release_mode': false});
      expect(json['drifts'], isEmpty);
      expect(json['ts'], '2026-09-05T18:30:00.000Z');
      // fix is omitted when there is nothing to fix.
      expect(json.containsKey('fix'), isFalse);
    });

    test('toJsonLine emits one parseable single-line JSON document', () {
      final line = VerdictEnvelope(
        command: 'zfa tdd make',
        result: VerdictResult.error,
        exitCode: ExitClass.failure,
        message: 'feature Foo already exists',
        data: {'feature': 'Foo'},
        fix: 'zfa make Foo --methods=get',
      ).toJsonLine();

      expect(line, isNot(contains('\n')));
      final decoded = jsonDecode(line) as Map<String, Object?>;
      expect(decoded['schema'], 'zuraffa.verdict.v1');
      expect(decoded['result'], 'error');
      expect(decoded['exit_class'], 1);
      expect(decoded['fix'], 'zfa make Foo --methods=get');
    });

    test('emitVerdict prints the envelope and returns the emitted line', () {
      final captured = <String>[];
      final line = emitVerdict(
        command: 'zfa benchmark list',
        result: VerdictResult.ok,
        message: '0 scenarios registered',
        data: {'scenarios': <Object?>[]},
        printSink: captured.add,
      );

      expect(captured, [line]);
      expect(line, contains('"schema":"zuraffa.verdict.v1"'));
      final decoded = jsonDecode(line) as Map<String, Object?>;
      expect(decoded['result'], 'ok');
      expect((decoded['data'] as Map<String, Object?>)['scenarios'], isEmpty);
    });

    test('exitClass maps the ratified protocol codes', () {
      expect(ExitClass.success, 0);
      expect(ExitClass.failure, 1);
      expect(ExitClass.usage, 2);
      expect(ExitClass.drift, 3);
      expect(ExitClass.conflict, 4);
    });

    test('isVerdictEnvelope recognizes a canonical document', () {
      final good = jsonDecode(
            '{"schema":"zuraffa.verdict.v1","command":"zfa x","result":"ok",'
            '"exit_class":0,"message":"m","data":{},"drifts":[],'
            '"ts":"2026-09-05T18:30:00Z"}',
          )
          as Map<String, Object?>;
      expect(isVerdictEnvelope(good), isTrue);

      final legacy = <String, Object?>{'schema': 'verdict.v1', 'verdict': 'pass'};
      expect(isVerdictEnvelope(legacy), isFalse);
    });
  });
}
