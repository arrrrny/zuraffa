// U4 (feature 071): persistence marking is DECLARED, not sniffed. A
// `[persistent]` FR tag or a trace to a `storage:` dependency row
// marks the behavior; storage vocabulary in prose without a
// declaration does NOT (the #833 keyword trigger is retired — the
// spec's AC2 pins the unmarked default; false positives by
// construction were the defect). Issue #951; spec FR-006.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const _header = '''
**Template Version**: `zuraffa-1.0`

# Spec: 071-persistence

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
|-----------|------|----------|---------------|
| Hive | storage | `read(key) -> Object?` | P1 |

## Functional Requirements

## Acceptance Scenarios

1. **Given** a calculator **When** asked **Then** returns 42 when invoked with no args
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  const featureName = '071-persistence';

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('persistence_decl_');
    featureDir = p.join(tmpDir.path, 'specs', featureName);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<String> runPlan(String frBlock) async {
    await Directory(featureDir).create(recursive: true);
    final body = _header.replaceFirst(
      '## Functional Requirements\n',
      '## Functional Requirements\n\n$frBlock\n',
    );
    await File(p.join(featureDir, 'spec.md')).writeAsString(body);
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing([
      'tdd',
      'plan',
      featureName,
      '--project',
      tmpDir.path,
    ]);
    return File(
      p.join(featureDir, 'tdd', 'test-list.md'),
    ).readAsStringSync();
  }

  test('a [persistent] tag marks the behavior (no storage words needed)',
      () async {
    final list = await runPlan(
      '- **FR-001**: [persistent] the cart survives an app restart',
    );
    expect(
      list,
      contains(
        '| U1 | the cart survives an app restart [persistence] | FR-001 | PENDING |',
      ),
      reason: 'tag stripped from the description; the mark is appended',
    );
    expect(list, contains('[persistence]'));
  });

  test('storage vocabulary WITHOUT a declaration stays unmarked (AC2)',
      () async {
    final list = await runPlan(
      '- **FR-001**: caches the result for display alongside the query',
    );
    expect(
      list,
      contains(
        '| U1 | caches the result for display alongside the query | FR-001 | PENDING |',
      ),
    );
  });

  test('a trace to a storage dependency marks the behavior', () async {
    final list = await runPlan(
      '- **FR-001**: the offline queue replays after reconnect\n'
      '            traces: Hive',
    );
    expect(list, contains('[persistence]'));
    expect(list, contains('the offline queue replays after reconnect'));
  });
}
