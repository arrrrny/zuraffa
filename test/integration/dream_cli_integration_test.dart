@Tags(['slow', 'integration'])
// U9 (integration tier) for spec 1010-zfa-dream-one-command-app: the
// REAL `zfa dream` CLI drives the full pipeline end-to-end — the
// deterministic drafter (no LLM configured), REAL subprocess ingest +
// plan through an exec-forwarder fake zfa bin (the sc_018 pattern:
// ingest/plan exec the real CLI; run/view are canned), the two
// receipts, and the verdict.v1 envelope. The LIVE equivalent (same
// flow, real dart spawns, recorded from this session) is in
// specs/1010-zfa-dream-one-command-app/tdd/verification.md.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/project_root.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dream_cli_int_');
  });

  tearDown(() async {
    exitCode = 0;
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  const description =
      'A page that lists the user\'s favorite deals, sorted by expiration';

  test('U9 (integration): the real CLI drives the full pipeline '
      '(--no-pr, --json envelope)', () async {
    final repoRoot = await findProjectRoot();
    final fakeBin = await _writeExecForwarder(tmp, repoRoot);

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'dream',
      description,
      '--project',
      tmp.path,
      '--zfa-bin',
      fakeBin,
      '--no-pr',
    ]);

    expect(
      out,
      contains('dream:'),
      reason: 'the top-level command must exist and run',
    );
    expect(exitCode, 0, reason: out);
    expect(out, contains('engine=green'), reason: out);
    expect(out, contains('skin=green'), reason: out);
    expect(out, contains('drafter=deterministic'), reason: out);

    // The deterministic drafter + the REAL forwarded ingest/plan: the
    // artifact set landed on disk (the issue #1010 exit criterion
    // artifact list, minus the PR phase which --no-pr skips).
    final dir = Directory(p.join(tmp.path, 'specs', '001-favorite-deal'));
    expect(dir.existsSync(), isTrue, reason: out);
    for (final rel in [
      'spec.md',
      'plan.md',
      'tdd/test-list.md',
      'tdd/traceability.md',
      'tdd/draft-spec.md',
    ]) {
      expect(
        File(p.join(dir.path, rel)).existsSync(),
        isTrue,
        reason: 'missing $rel\n$out',
      );
    }
    final receipts = Directory(p.join(tmp.path, '.zfa', 'receipts'))
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).contains('dream-'))
        .toList();
    expect(receipts.length, 2, reason: receipts.join(','));
    final bodies = receipts.map((f) => f.readAsStringSync()).join('\n');
    expect(bodies, contains('"command": "dream-engine"'));
    expect(bodies, contains('"command": "dream-skin"'));

    // --json emits the verdict.v1 envelope as the final line.
    final tmp2 = await Directory.systemTemp.createTemp('dream_cli_int2_');
    addTearDown(() => tmp2.delete(recursive: true));
    final out2 = await runner.runCapturing([
      'dream',
      description,
      '--project',
      tmp2.path,
      '--zfa-bin',
      fakeBin,
      '--no-pr',
      '--json',
    ]);
    expect(out2, contains('verdict.v1'));
    final last = out2.trim().split('\n').last;
    expect(jsonDecode(last), isA<Map<String, dynamic>>());
    expect((jsonDecode(last) as Map)['command'], 'dream');
  }, timeout: Timeout(Duration(minutes: 5)));
}

/// The exec-forwarder fake zfa bin (the sc_018 pattern): ingest/plan
/// exec the REAL CLI; run/view are canned.
Future<String> _writeExecForwarder(Directory tmp, String repoRoot) async {
  final dart = Platform.resolvedExecutable;
  final script =
      '''
#!/bin/sh
# Fake zfa bin for the dream U9 integration test: forward ingest/plan to
# the real CLI (exec), script the run/view phases.
case "\$2" in
  run)
    echo "[run] A-1 gen -> ok"
    echo "run: feature=\$3 result=complete pending=0 red=0 green=1 done=1"
    exit 0
    ;;
  view)
    echo "view: behavior=\$3 outcome=already-implemented feature=\$5"
    exit 0
    ;;
  *)
    exec "$dart" "$repoRoot/bin/zfa.dart" "\$@"
    ;;
esac
''';
  final dir = Directory(p.join(tmp.path, 'fake-bin'));
  await dir.create(recursive: true);
  final f = File(p.join(dir.path, 'fake-zfa.sh'));
  await f.writeAsString(script);
  final chmod = await Process.run('chmod', ['+x', f.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return f.path;
}
