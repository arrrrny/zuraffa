// ZAP demo (spec 071, issue #809) — the FOREIGN CLIENT.
//
// An independent implementation of the Zuraffa Agent Protocol built ONLY
// against the published contract (specs/071-zuraffa-agent-protocol/
// contracts/zap.md + schemas/*.schema.json + golden/*.golden.json):
// pure dart:io + dart:convert, ZERO zuraffa imports, no pubspec. That
// independence is the interop argument (issue #809's second done-when).
//
// It spawns a real `zfa zap serve` host, drives a FULL TDD LOOP:
//
//   mission 1  {red, green}  -> evidence x2 + receipt (pass)
//   checkpoint save          -> saved (stateId + digest)
//   checkpoint restore       -> restored (session rebuilt)
//   mission 2  {verify}      -> evidence + receipt (pass, cumulative chain)
//
// ...then independently recomputes the evidence chain (sha256,
// null-separated certified facts, genesis-linked) and compares it with
// the receipt's chainDigest — receipt verification from the OUTSIDE.
//
// Output: the final line of stdout is one JSON object:
//   {"chainVerified": <bool>, "hostCommand": "dart bin/zfa.dart zap serve",
//    "receipt": {…}}
// Exit code: the receipt's exit (0 pass / 1 fail), or 2 on a client-side
// failure to drive the session.
//
// Usage: dart examples/zap_demo/foreign_client.dart [--repo-root <path>]

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sha256.dart';

const zapVersion = '0.1';
const genesis = 'genesis';

void main(List<String> args) async {
  final repoRoot = _repoRoot(args);
  final hostCommand = 'dart bin/zfa.dart zap serve';

  final host = await Process.start('dart', [
    'bin/zfa.dart',
    'zap',
    'serve',
  ], workingDirectory: repoRoot);

  final reader = _LineReader(host.stdout);

  try {
    // ---- Mission 1: red + green (the core TDD loop) -------------------
    _log('client: submitting mission 1 (red + green)');
    host.stdin.writeln(
      jsonEncode(
        _mission(
          id: 'm-demo-1',
          missionId: 'demo-tdd',
          steps: [
            _step(
              's1',
              'dart examples/zap_demo/tdd_loop.dart red',
              'red',
              'witness the failing check',
            ),
            _step(
              's2',
              'dart examples/zap_demo/tdd_loop.dart green',
              'green',
              'the fixed check passes',
            ),
          ],
        ),
      ),
    );

    final evidence1 = [await reader.nextLine(), await reader.nextLine()];
    final receipt1 = _decode(await reader.nextLine());
    _log('client: mission 1 receipt verdict=${receipt1['verdict']}');

    // ---- Checkpoint save + restore ------------------------------------
    _log('client: checkpoint save');
    host.stdin.writeln(jsonEncode(_checkpoint('c-1', 'demo-tdd', 'save')));
    final saved = _decode(await reader.nextLine());
    final stateId = saved['stateId'] as String;

    _log('client: checkpoint restore $stateId');
    host.stdin.writeln(
      jsonEncode(_checkpoint('c-2', 'demo-tdd', 'restore', stateId: stateId)),
    );
    final restored = _decode(await reader.nextLine());
    if (restored['kind'] != 'restored') {
      stderr.writeln('client: restore failed: $restored');
      exit(2);
    }

    // ---- Mission 2: verify (the loop completes) ------------------------
    _log('client: submitting mission 2 (verify)');
    host.stdin.writeln(
      jsonEncode(
        _mission(
          id: 'm-demo-2',
          missionId: 'demo-tdd',
          steps: [
            _step(
              's3',
              'dart examples/zap_demo/tdd_loop.dart verify',
              'verify',
              'the suite is green',
            ),
          ],
        ),
      ),
    );

    final evidence2 = [await reader.nextLine()];
    final receipt = _decode(await reader.nextLine());

    // ---- Receipt verification (from the outside) -----------------------
    final facts = [...evidence1, ...evidence2].map(_decode).toList();
    final chainVerified = _recomputeChain(facts) == receipt['chainDigest'];
    final verdictOk = receipt['verdict'] == 'pass' && receipt['exit'] == 0;
    final disciplineOk =
        ((receipt['checks'] as List).cast<Map>().firstWhere(
          (c) => c['name'] == 'tdd-discipline',
        ))['ok'] ==
        true;

    // ---- Tear down and report ------------------------------------------
    host.stdin.close();
    final hostExit = await host.exitCode;

    final report = {
      'chainVerified': chainVerified,
      'hostCommand': hostCommand,
      'hostExit': hostExit,
      'receipt': receipt,
      'evidenceCount': facts.length,
    };
    stdout.writeln(jsonEncode(report));

    exit(
      verdictOk && chainVerified && disciplineOk ? receipt['exit'] as int : 1,
    );
  } catch (e) {
    stderr.writeln('client: session failed: $e');
    host.kill();
    exit(2);
  }
}

// ---------------------------------------------------------------------------
// Hand-rolled ZAP messages (per the published schemas — no shared code
// with the reference implementation)
// ---------------------------------------------------------------------------

Map<String, Object?> _mission({
  required String id,
  required String missionId,
  required List<Map<String, Object?>> steps,
}) => {
  'zap': zapVersion,
  'type': 'mission',
  'id': id,
  'ts': _now(),
  'missionId': missionId,
  'agent': 'foreign-client',
  'goal': 'Drive a full TDD loop',
  'feature': '071-zuraffa-agent-protocol',
  'budget': {'maxSteps': 8},
  'policy': {
    'riskTier': 'standard',
    'toolAllowlist': ['dart'],
  },
  'steps': steps,
};

Map<String, Object?> _step(
  String id,
  String command,
  String phase,
  String description,
) => {'id': id, 'command': command, 'phase': phase, 'description': description};

Map<String, Object?> _checkpoint(
  String id,
  String missionId,
  String kind, {
  String? stateId,
}) => {
  'zap': zapVersion,
  'type': 'checkpoint',
  'id': id,
  'ts': _now(),
  'missionId': missionId,
  'kind': kind,
  'stateId': ?stateId,
};

Map<String, Object?> _decode(String line) =>
    (jsonDecode(line) as Map).cast<String, Object?>();

String _now() => DateTime.now().toUtc().toIso8601String();

void _log(String message) => stderr.writeln(message);

// ---------------------------------------------------------------------------
// The evidence chain, reimplemented from the contract text (§5) — the
// whole point: an INDEPENDENT implementation of receipt verification.
// ---------------------------------------------------------------------------

String _recomputeChain(List<Map<String, Object?>> facts) {
  var link = genesis;
  for (final fact in facts) {
    final payload = [
      'v$zapVersion',
      fact['missionId'],
      fact['stepId'],
      fact['phase'],
      fact['command'],
      fact['exit'],
      fact['digest'],
      fact['at'],
      link,
    ].join('\x00');
    final bytes = utf8.encode(payload);
    link = demoSha256Hex(bytes);
  }
  return link;
}

// ---------------------------------------------------------------------------
// Plumbing
// ---------------------------------------------------------------------------

class _LineReader {
  _LineReader(Stream<List<int>> stream) {
    _lines = StreamIterator(
      stream.transform(const Utf8Decoder()).transform(const LineSplitter()),
    );
  }

  late final StreamIterator<String> _lines;

  Future<String> nextLine() async {
    final hasLine = await _lines.moveNext().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw TimeoutException('host did not reply'),
    );
    if (!hasLine) {
      throw StateError('host closed its stdout before replying');
    }
    return _lines.current;
  }
}

String _repoRoot(List<String> args) {
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--repo-root') return args[i + 1];
  }
  // Walk up from CWD until bin/zfa.dart exists.
  var dir = Directory.current;
  for (var i = 0; i < 20; i++) {
    if (File('${dir.path}/bin/zfa.dart').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  stderr.writeln(
    'client: cannot locate the repo root (bin/zfa.dart); '
    'pass --repo-root <path>',
  );
  exit(2);
}
