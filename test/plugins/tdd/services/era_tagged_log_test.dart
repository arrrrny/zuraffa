// Fast unit tests for `EraTaggedLog` — era-tagged, hash-chained cycle-log
// evidence (spec 913, T005: U17-U18).
//
//   U17: appended entries carry `- era: MOCKED|REAL` and the schema-1
//        hash chain (prev-hash/hash) over an era-aware payload.
//   U18: the last era tag is read back from the cycle log and survives
//        across appended entries (evidence per era).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/era_tagged_log.dart';
import 'package:zuraffa/src/plugins/tdd/services/realize_state.dart';

void main() {
  late Directory temp;
  late String featureDir;
  late String logPath;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('era_log_');
    featureDir = p.join(temp.path, 'specs', '090-tdd-fixture');
    logPath = p.join(featureDir, 'tdd', 'cycle-log.md');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  EraTaggedLogEntry entry({
    required RealizeEra era,
    String behavior = 'user-realize',
    int exit = 0,
  }) =>
      EraTaggedLogEntry(
        behaviorId: behavior,
        kind: 'realize',
        era: era,
        criterion: 'SC-4',
        test: '-',
        command: 'zfa tdd realize User --adapter UserRealAdapter',
        exitCode: exit,
        output: 'realize: result=realized',
      );

  test('U17: entries carry era tags and a verifiable hash chain', () async {
    final log = EraTaggedLog(featureDir);

    await log.append(entry(era: RealizeEra.mocked, exit: 1));
    await log.append(entry(era: RealizeEra.real, exit: 0));

    final raw = await File(logPath).readAsString();
    expect(raw, contains('- era: MOCKED'));
    expect(raw, contains('- era: REAL'));
    expect(raw, contains('- schema: 1'));
    expect(raw, contains('- kind: realize'));

    // Both entries are hashed (64-hex) and chained: the second entry's
    // prev-hash equals the first entry's hash (same behavior chain).
    final hashes =
        RegExp(r'^- hash: ([0-9a-f]{64})$', multiLine: true)
            .allMatches(raw)
            .map((m) => m.group(1)!)
            .toList();
    final prevs =
        RegExp(r'^- prev-hash: (\S+)$', multiLine: true)
            .allMatches(raw)
            .map((m) => m.group(1)!)
            .toList();
    expect(hashes, hasLength(2));
    expect(prevs, hasLength(2));
    expect(prevs.first, 'genesis');
    expect(prevs.last, hashes.first,
        reason: 'the second entry chains onto the first');

    // The chain hash is era-aware: recomputing it from the entry's fields
    // (with the right prev) reproduces the recorded hash.
    expect(
      EraTaggedLog.chainHashFor(
        entry(era: RealizeEra.real),
        hashes.first,
      ),
      hashes.last,
    );

    // A different era changes the hash (the era is INSIDE the payload).
    expect(
      EraTaggedLog.chainHashFor(entry(era: RealizeEra.mocked), hashes.first),
      isNot(hashes.last),
    );
  });

  test('U18: lastEra() reads the era back and survives across entries',
      () async {
    final log = EraTaggedLog(featureDir);

    // No entries yet: no era recorded.
    expect(await log.lastEra(), isNull);

    await log.append(entry(era: RealizeEra.mocked, exit: 1));
    expect(await log.lastEra(), RealizeEra.mocked);

    await log.append(entry(era: RealizeEra.real, exit: 0));
    expect(await log.lastEra(), RealizeEra.real,
        reason: 'the REAL era survives after the MOCKED-era entry');

    // A later MOCKED-era entry (a blocked re-run) is visible too — the
    // era follows the log, not the state file.
    await log.append(entry(era: RealizeEra.mocked, exit: 1));
    expect(await log.lastEra(), RealizeEra.mocked);
  });
}
