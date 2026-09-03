// Bug #833 (tdd-persistence-test-harness) — the plan marks the behavior
// persistence-kind so `zfa tdd gen` generates the harness-backed test.
//
// Feature 071 (issue #951) CHANGED THE TRIGGER by spec (FR-006/AC2):
// the mark lands on a DECLARED `[persistent]` FR tag or a trace to a
// `storage:` dependency row. The #833 keyword sniffing (Hive, cache,
// TTL, offline, corruption, registrar, persistence) is retired —
// storage vocabulary without a declaration stays unmarked (it was
// false-positive-prone by construction). These pins now assert the
// DECLARED contract; the keyword-era pins were re-pointed, not
// weakened: the mark's shape, idempotency, and non-persistence
// default are unchanged.
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
    // Bug #919: persistence prose names Hive, a known external — the
    // undeclared-dependency lint would exit 2 before the persistence
    // marking path runs, so the fixture declares it in the template's
    // table (the marking behavior asserted here is unaffected).
    await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: $featureName

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
|-----------|------|----------|---------------|
| Hive | storage | `read(key) -> Object?` | P1 |

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
- **FR-001**: [persistent] cached listing is served from Hive with a 24h TTL
- **FR-002**: [persistent] corrupted box recovers through the clear + re-fetch path
''');
    final list = await runPlan();
    expect(
      list,
      contains(
        'cached listing is served from Hive with a 24h TTL [persistence]',
      ),
      reason:
          'the declared tag marks the behavior persistence-kind (the prose '
          'alone no longer does — feature 071)',
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
- **FR-001**: [persistent] offline queue replays against the cache after reconnect
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

  test('feature 071: storage vocabulary WITHOUT a declaration stays '
      'unmarked (the keyword trigger is retired)', () async {
    await seedSpec('''
- **FR-001**: caches the result for display alongside the query
''');
    final list = await runPlan();
    expect(
      list,
      contains(
        '| U1 | caches the result for display alongside the query | FR-001 | PENDING |',
      ),
    );
  });
}
