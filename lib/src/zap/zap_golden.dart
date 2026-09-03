/// ZAP golden examples (spec 071, issue #809, FR-006).
///
/// One canonical message per core type — the same examples the
/// conformance suite validates, the committed `golden/*.golden.json`
/// files carry, and third parties validate their implementations against.
/// The evidence digest is the real sha256 of the canonical output string
/// (derived, never hand-typed), so the golden is internally consistent by
/// construction.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'zap_chain.dart';
import 'zap_protocol.dart';

const String _redOutput =
    'ZAP DEMO red: 1 check FAILED (by design) '
    '— add(2, 3) returned 6, expected 5';

String _sha256Of(String text) => sha256.convert(utf8.encode(text)).toString();

/// Golden examples for the four core message types.
abstract final class ZapGoldens {
  /// The canonical example for [type] (`mission`, `evidence`,
  /// `checkpoint`, `receipt`); fresh deep copies every call.
  static Map<String, Object?> example(String type) {
    final map = switch (type) {
      'mission' => _mission(),
      'evidence' => _evidence(),
      'checkpoint' => _checkpoint(),
      'receipt' => _receipt(),
      _ => throw ArgumentError.value(
        type,
        'type',
        'no golden example (expected mission|evidence|'
            'checkpoint|receipt)',
      ),
    };
    // Deep copy via JSON round-trip: callers may mutate freely.
    return (jsonDecode(jsonEncode(map)) as Map).cast<String, Object?>();
  }

  static Map<String, Object?> _mission() => <String, Object?>{
    'zap': zapProtocolVersion,
    'type': 'mission',
    'id': 'm-demo-0001',
    'ts': '2026-09-03T10:00:00Z',
    'missionId': 'demo-tdd',
    'agent': 'foreign-client',
    'goal': 'Drive a full TDD loop',
    'feature': '071-zuraffa-agent-protocol',
    'budget': {'maxSteps': 8},
    'policy': {
      'riskTier': 'standard',
      'toolAllowlist': ['dart'],
    },
    'steps': [
      {
        'id': 's1',
        'command': 'dart examples/zap_demo/tdd_loop.dart red',
        'phase': 'red',
        'description': 'witness the failing check',
        'timeoutSeconds': 30,
      },
      {
        'id': 's2',
        'command': 'dart examples/zap_demo/tdd_loop.dart green',
        'phase': 'green',
        'description': 'the fixed check passes',
      },
    ],
  };

  static Map<String, Object?> _evidence() => <String, Object?>{
    'zap': zapProtocolVersion,
    'type': 'evidence',
    'id': 'e-demo-0001',
    'ts': '2026-09-03T10:00:01Z',
    'missionId': 'demo-tdd',
    'stepId': 's1',
    'phase': 'red',
    'command': 'dart examples/zap_demo/tdd_loop.dart red',
    'exit': 1,
    'digest': _sha256Of(_redOutput),
    'at': '2026-09-03T10:00:01Z',
    'durationMs': 412,
    'output': _redOutput,
  };

  static Map<String, Object?> _checkpoint() => <String, Object?>{
    'zap': zapProtocolVersion,
    'type': 'checkpoint',
    'id': 'c-demo-0001',
    'ts': '2026-09-03T10:00:02Z',
    'missionId': 'demo-tdd',
    'kind': 'saved',
    'stateId': 'cp-9d8c7b6a5f4e3',
    'digest': 'a' * 64,
    'steps': 2,
    'at': '2026-09-03T10:00:02Z',
  };

  static Map<String, Object?> _receipt() => <String, Object?>{
    'zap': zapProtocolVersion,
    'type': 'receipt',
    'id': 'r-demo-0001',
    'ts': '2026-09-03T10:00:03Z',
    'missionId': 'demo-tdd',
    'verdict': 'pass',
    'exit': 0,
    // The demo's three-step chain (red, green, verify) with the
    // canonical facts — recomputed so the golden receipt is exactly
    // what an honest host would emit for the golden session.
    'chainDigest': _demoChainDigest(),
    'stepsExecuted': 3,
    'stepsTotal': 3,
    'checks': [
      {'name': 'mission-schema', 'ok': true},
      {'name': 'budget', 'ok': true},
      {'name': 'policy', 'ok': true},
      {'name': 'steps-executed', 'ok': true},
      {'name': 'tdd-discipline', 'ok': true},
      {'name': 'evidence-chain', 'ok': true},
    ],
    'at': '2026-09-03T10:00:03Z',
  };

  /// The chain over the canonical demo facts: red (exit 1), green
  /// (exit 0), verify (exit 0) — the golden session's evidence.
  static String _demoChainDigest() {
    var link = zapGenesisLink;
    for (final fact in _demoFacts()) {
      link = zapChainLink(fact: fact, prevLink: link);
    }
    return link;
  }

  static List<Map<String, Object?>> _demoFacts() => [
    {
      'missionId': 'demo-tdd',
      'stepId': 's1',
      'phase': 'red',
      'command': 'dart examples/zap_demo/tdd_loop.dart red',
      'exit': 1,
      'digest': _sha256Of(_redOutput),
      'at': '2026-09-03T10:00:01Z',
    },
    {
      'missionId': 'demo-tdd',
      'stepId': 's2',
      'phase': 'green',
      'command': 'dart examples/zap_demo/tdd_loop.dart green',
      'exit': 0,
      'digest': _sha256Of(
        'ZAP DEMO green: 1 check passed (by design) '
        '— add(2, 3) returned 5, expected 5',
      ),
      'at': '2026-09-03T10:00:02Z',
    },
    {
      'missionId': 'demo-tdd',
      'stepId': 's3',
      'phase': 'verify',
      'command': 'dart examples/zap_demo/tdd_loop.dart verify',
      'exit': 0,
      'digest': _sha256Of(
        'ZAP DEMO verify: 3 checks passed — the '
        'suite is green',
      ),
      'at': '2026-09-03T10:00:03Z',
    },
  ];
}
