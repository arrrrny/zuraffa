// Tests for CycleEvidence (spec 049-tdd-run, U4-U6 / T006).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/cycle_evidence.dart';

void main() {
  late Directory tmp;
  late String featureDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cycle_evidence_');
    featureDir = p.join(tmp.path, 'specs', '090-fixture');
    await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> seedLog(String content) async {
    await File(
      p.join(featureDir, 'tdd', 'cycle-log.md'),
    ).writeAsString(content);
  }

  test('U4: red evidence = behaviors with a kind: red section', () async {
    await seedLog('''
# Cycle Log: 090-fixture

## Cycle: B-001 (red)

- behavior: B-001
- kind: red
- classification: assertionFailure
- exit: 1

## Cycle: B-002 (green)

- behavior: B-002
- kind: green
- exit: 0

## Cycle: B-003 (red)

- behavior: B-003
- kind: red
- classification: assertionFailure
- exit: 1

## Baseline

- suite: dart test -> 3 passed
''');

    final evidence = CycleEvidence(featureDir);

    expect(await evidence.redEvidence(), {'B-001', 'B-003'});
  });

  test('U5: green evidence = behaviors with a kind: green section', () async {
    await seedLog('''
## Cycle: B-001 (red)

- behavior: B-001
- kind: red

## Cycle: B-001 (green)

- behavior: B-001
- kind: green

## Notes

- deliberate mutant check on B-001 restored; suite green
''');

    final evidence = CycleEvidence(featureDir);

    expect(await evidence.greenEvidence(), {'B-001'});
  });

  test('U6: a missing cycle log yields empty sets, not an error', () async {
    final evidence = CycleEvidence(featureDir);

    expect(await evidence.redEvidence(), isEmpty);
    expect(await evidence.greenEvidence(), isEmpty);
  });

  test('a section without a behavior line contributes nothing', () async {
    await seedLog('''
## Baseline

- suite: dart test -> 3 passed
- kind: red

## Cycle: (red)

- kind: red
''');

    final evidence = CycleEvidence(featureDir);

    expect(await evidence.redEvidence(), isEmpty);
    expect(await evidence.greenEvidence(), isEmpty);
  });
}
