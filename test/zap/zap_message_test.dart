// Spec 071 (issue #809) — ZAP typed message layer + evidence chain.
//
// U8–U11 from specs/071-zuraffa-agent-protocol/tdd/test-list.md: the NDJSON
// line codec round-trips; the five typed messages round-trip with stable
// key order; malformed input throws with path evidence; the evidence
// chain is tamper-evident (FR-001..005, FR-013).
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/zap/zap_chain.dart';
import 'package:zuraffa/src/zap/zap_golden.dart';
import 'package:zuraffa/src/zap/zap_message.dart';
import 'package:zuraffa/src/zap/zap_protocol.dart';

void main() {
  group('ZapProtocol — NDJSON line codec (U8)', () {
    test('U8: encodeLine/decodeLine round-trip a message map', () {
      final msg = ZapGoldens.example('mission');
      final line = ZapProtocol.encodeLine(msg);
      expect(line.endsWith('\n'), isTrue, reason: 'NDJSON lines end in \\n');
      expect(ZapProtocol.decodeLine(line), msg);
    });

    test('U8: garbage lines throw FormatException', () {
      expect(
        () => ZapProtocol.decodeLine('this is not json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ZapProtocol.decodeLine('[1,2,3]\n'),
        throwsA(isA<FormatException>()),
      );
    });

    test('U8: the protocol version is 0.1 (the v0 slice)', () {
      expect(zapProtocolVersion, '0.1');
    });
  });

  group('ZapMessage — typed round-trips (U9)', () {
    for (final type in ['mission', 'evidence', 'checkpoint', 'receipt']) {
      test('U9: the golden $type round-trips with stable key order', () {
        final golden = ZapGoldens.example(type);
        final typed = ZapMessage.fromJson(golden);
        final encoded = typed.toJson();

        expect(
          encoded,
          golden,
          reason: '$type: fromJson(toJson()) must equal the golden map',
        );

        // Stable key order: re-encoding is byte-identical.
        expect(jsonEncode(encoded), jsonEncode(golden));
      });
    }

    test('U9: an error message round-trips too', () {
      final error = ZapMessage.fromJson({
        'zap': '0.1',
        'type': 'error',
        'id': 'x-1',
        'ts': '2026-09-03T10:00:00Z',
        'code': 'schema',
        'message': 'nope',
        'inReplyTo': 'm-9',
        'details': ['steps[0].phase: must be one of red|green|refactor|verify'],
      });
      expect(error, isA<ZapError>());
      final out = error.toJson();
      expect(out['code'], 'schema');
      expect(out['inReplyTo'], 'm-9');
      expect((out['details'] as List).length, 1);
    });

    test('U9: typed accessors expose the certified facts', () {
      final mission =
          ZapMessage.fromJson(ZapGoldens.example('mission')) as MissionEnvelope;
      expect(mission.missionId, 'demo-tdd');
      expect(mission.maxSteps, 8);
      expect(mission.riskTier, 'standard');
      expect(mission.steps.length, 2);
      expect(mission.steps.first.phase, 'red');
      expect(mission.steps.first.timeoutSeconds, 30);

      final evidence =
          ZapMessage.fromJson(ZapGoldens.example('evidence')) as EvidencePacket;
      expect(evidence.stepId, 's1');
      expect(evidence.phase, 'red');
      expect(evidence.exit, 1);
      expect(evidence.command, contains('tdd_loop.dart'));

      final receipt =
          ZapMessage.fromJson(ZapGoldens.example('receipt')) as ZapReceipt;
      expect(receipt.verdict, 'pass');
      expect(receipt.exit, 0);
      expect(receipt.checks.length, 6);
      expect(receipt.checks.every((c) => c.ok), isTrue);
    });
  });

  group('ZapMessage — malformed input (U10)', () {
    test('U10: schema violations throw ZapSchemaException with paths', () {
      final broken = ZapGoldens.example('mission')..remove('goal');
      expect(
        () => ZapMessage.fromJson(broken),
        throwsA(
          isA<ZapSchemaException>().having(
            (e) => e.issues.any((i) => i.path == 'goal'),
            'issues name the missing field',
            isTrue,
          ),
        ),
      );
    });

    test('U10: a bad enum value is reported at its path', () {
      final broken = ZapGoldens.example('mission');
      ((broken['steps'] as List)[0] as Map)['phase'] = 'vibes';
      expect(
        () => ZapMessage.fromJson(broken),
        throwsA(
          isA<ZapSchemaException>().having(
            (e) => e.issues.any((i) => i.path == 'steps[0].phase'),
            'issues name the enum path',
            isTrue,
          ),
        ),
      );
    });

    test('U10: a wrong zap version throws with a version classification', () {
      final broken = ZapGoldens.example('mission');
      broken['zap'] = '2.0';
      expect(
        () => ZapMessage.fromJson(broken),
        throwsA(
          isA<ZapSchemaException>()
              .having((e) => e.classification, 'classification', 'version')
              .having((e) => e.issues, 'issues', isNotEmpty),
        ),
      );
    });
  });

  group('zapEvidenceChain — receipt verification primitive (U11)', () {
    Map<String, Object?> fact(String stepId, String phase, int exit) => {
      'missionId': 'demo-tdd',
      'stepId': stepId,
      'phase': phase,
      'command': 'dart examples/zap_demo/tdd_loop.dart $stepId',
      'exit': exit,
      'digest': 'a' * 64,
      'at': '2026-09-03T10:00:0${stepId}Z',
    };

    test('U11: the chain over three facts produces genesis-linked links', () {
      final facts = [
        fact('1', 'red', 1),
        fact('2', 'green', 0),
        fact('3', 'verify', 0),
      ];
      final head = zapEvidenceChain(facts);

      // The head is a sha256 hex digest.
      expect(head, matches(RegExp('^[a-f0-9]{64}\$')));

      // The head equals the manually-folded chain from genesis.
      var link = zapGenesisLink;
      for (final f in facts) {
        link = zapChainLink(fact: f, prevLink: link);
      }
      expect(head, link);
    });

    test('U11: mutating any certified fact changes the head', () {
      final facts = [fact('1', 'red', 1), fact('2', 'green', 0)];
      final honestHead = zapEvidenceChain(facts);

      final tampered = [fact('1', 'red', 1), fact('2', 'green', 1)];
      expect(
        zapEvidenceChain(tampered),
        isNot(honestHead),
        reason: 'flipping an exit code must change the chain head',
      );

      final reordered = [fact('2', 'green', 0), fact('1', 'red', 1)];
      expect(
        zapEvidenceChain(reordered),
        isNot(honestHead),
        reason: 'reordering evidence must change the chain head',
      );
    });

    test('U11: an empty chain is the genesis link', () {
      expect(zapEvidenceChain([]), zapGenesisLink);
    });
  });
}
