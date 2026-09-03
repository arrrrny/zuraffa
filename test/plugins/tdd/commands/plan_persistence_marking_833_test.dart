// Bug #833 (tdd-persistence-test-harness) — the plan marks the behavior
// persistence-kind.
//
// `zfa tdd plan` marks behaviors whose prose names persistence concerns
// (Hive, cache, TTL, offline, corruption, registrar, persistence) by
// appending the ` [persistence]` marker to the behavior cell, so that
// `zfa tdd gen` generates the harness-backed test for them. Behaviors that
// do not touch persistence stay unmarked (plain shape).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmpDir;
  late String featureDir;
  const featureName = '005-caching';

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('plan_persistence_833_');
    featureDir = p.join(tmpDir.path, 'specs', featureName);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedSpec(String body) async {
    await Directory(featureDir).create(recursive: true);
    await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: $featureName

## Functional Requirements

$body

## Acceptance Scenarios

1. **Given** a calculator **When** the user asks for the answer **Then** returns 42 when invoked with no args
''');
  }

  Future<String> runPlan() async {
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing([
      'tdd',
      'plan',
      featureName,
      '--project',
      tmpDir.path,
    ]);
    return File(p.join(featureDir, 'tdd', 'test-list.md')).readAsStringSync();
  }

  test('persistence-worded FRs are marked with [persistence]', () async {
    await seedSpec('''
- **FR-001**: cached listing is served from Hive with a 24h TTL
- **FR-002**: corrupted box recovers through the clear + re-fetch path
''');
    final list = await runPlan();
    expect(
      list,
      contains(
        'cached listing is served from Hive with a 24h TTL [persistence]',
      ),
      reason: 'Hive/TTL wording marks the behavior persistence-kind',
    );
    expect(
      list,
      contains(
        'corrupted box recovers through the clear + re-fetch path [persistence]',
      ),
    );
  });

  test('non-persistence FRs are NOT marked', () async {
    await seedSpec('''
- **FR-001**: returns 42 when invoked with no args
''');
    final list = await runPlan();
    expect(
      list,
      contains(
        '| U1 | returns 42 when invoked with no args | FR-001 | PENDING |',
      ),
    );
    expect(
      list,
      isNot(contains('[persistence]')),
      reason: 'no persistence wording — no marker',
    );
  });

  test('the marker is idempotent across a re-plan', () async {
    await seedSpec('''
- **FR-001**: offline queue replays against the cache after reconnect
''');
    final first = await runPlan();
    expect(
      first,
      contains(
        'offline queue replays against the cache after reconnect [persistence]',
      ),
    );
    // Re-plan over the existing list — the reconciliation must not
    // double-tag the row.
    final second = await runPlan();
    expect(second, isNot(contains('[persistence] [persistence]')));
    expect(second, contains('[persistence]'));
  });
}
