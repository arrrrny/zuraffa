// Bug 1575: `ProofChainChecker._behaviorIdsOf` scans `tdd/test-list.md`
// (and lane plans) line-by-line with a fence-blind
// `startsWith('## ')` header detector — an in-fence `## ` line inside the
// behavior section (or a fenced `## Behaviors` example in a declarative
// section) flips `inBehaviorSection` like a real header: post-fence
// behavior ids silently vanish from the coverage audit, and a fenced
// example table fabricates phantom ids. Same defect class as #1467/#1549;
// the walk must route its `## ` header detection through the shared
// fence-aware splitter (`splitCycleLogSections()`).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/proof/proof_chain_checker.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zfa_proof_chain_1575_');
  });

  tearDown(() {
    if (root.existsSync()) {
      try {
        root.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  Future<void> seedTestList(String feature, String content) async {
    final file = File(
      p.join(root.path, 'specs', feature, 'tdd', 'test-list.md'),
    );
    await file.create(recursive: true);
    await file.writeAsString(content);
  }

  /// The `behavior_coverage` gaps of the check, as the behavior ids they
  /// name (the `expected` text embeds the id: green evidence for "B1").
  Future<Set<String>> coverageGapIds() async {
    final report = await ProofChainChecker(projectRoot: root.path).check();
    return report.items
        .where((i) => i.category == 'behavior_coverage')
        .map((i) => i.expected)
        .toSet();
  }

  test('1575: an in-fence header does not drop post-fence behavior ids',
      () async {
    await seedTestList('f1', '''
# Test List

## Behaviors

| # | Behavior | Trace | Test file |
|---|----------|-------|-----------|
| B1 | does x | FR-1 | test/x_test.dart |

```text
an example block inside the behaviors section
## Notes: not a behavior section
```

| B2 | does y | FR-2 | test/y_test.dart |
''');

    final gaps = await coverageGapIds();

    // No green evidence exists for either behavior: both must be reported.
    // The in-fence `## Notes:` banner must not switch the walk off the
    // behavior section (the legacy walk dropped B2 silently).
    expect(gaps.any((g) => g.contains('"B1"')), isTrue);
    expect(gaps.any((g) => g.contains('"B2"')), isTrue);
  });

  test('1575: a fenced `## Behaviors` example fabricates no phantom ids',
      () async {
    await seedTestList('f1', '''
# Test List

## Key entities

| entity | fields |
| ------ | ------ |
| Role | name:String |

```text
## Behaviors (example shape)
| PHANTOM | fake row | FR-x | test/fake_test.dart |
```
''');

    final gaps = await coverageGapIds();

    // The fenced example table sits in a declarative section; its banner
    // must not re-arm the behavior-section walk and its rows must never
    // become audit ids.
    expect(gaps.any((g) => g.contains('PHANTOM')), isFalse,
        reason: 'an in-fence example row is not a behavior');
    expect(gaps.any((g) => g.contains('"Role"')), isFalse,
        reason: 'declarations are not behaviors either');
  });

  test('1575: a well-formed behaviors table audits exactly as before',
      () async {
    await seedTestList('f1', '''
# Test List

## Behaviors

| # | Behavior | Trace | Test file |
|---|----------|-------|-----------|
| B1 | does x | FR-1 | test/x_test.dart |
| B2 | does y | FR-2 | test/y_test.dart |

## Key entities

| entity | fields |
| ------ | ------ |
| Role | name:String |
''');

    final gaps = await coverageGapIds();

    expect(gaps.any((g) => g.contains('"B1"')), isTrue);
    expect(gaps.any((g) => g.contains('"B2"')), isTrue);
    expect(gaps.any((g) => g.contains('"Role"')), isFalse);
  });
}
