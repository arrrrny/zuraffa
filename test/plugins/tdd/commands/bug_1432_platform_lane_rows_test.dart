// Bug #1432 — `zfa tdd plan`'s lane split routes a scenario typed
// `platform` to the SKIN lane in its route log while the emitted
// 04-SKIN.md omits the row; run then reports the lane green with
// spec-derived acceptance behaviors silently untested.
//
// Contract under test:
// 1. A platform-typed acceptance scenario renders as an outer-loop row in
//    its lane plan, exactly like an acceptance-typed one (exit 0).
// 2. The route log and the artifacts agree: every routed id appears as a
//    row in the lane plan the log names.
// 3. A routed kind no lane section renders (today: `theme`) refuses —
//    exit 2, refusal naming id/kind/criterion, NO lane artifacts written
//    (errors-are-an-API; the contract-kind path stays open #1419).
// 4. The plan summary's per-lane count equals the artifact's data-row
//    count, platform rows counted.
//
// RED phase: recorded against the unfixed tree — the platform row is
// dropped and the theme row exits 0.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const String feature = '004-login-ui';

/// SKIN lane declaring a platform-typed acceptance scenario (A1 — the
/// issue's shape), an acceptance-typed one (A2), and the FR-derived unit
/// behavior (U1) — every row lands in 04-SKIN.md.
const String platformLanesSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the platform channel **When** a reply arrives from the native side **Then** the reply maps to the typed envelope
   **Type**: platform
2. **Given** the user submits the login form **When** the fields are valid **Then** the session starts with the authenticated user
   **Type**: acceptance

## Layer Contracts

**Presentation**:
- `PlatformEnvelope`: `map(Reply) -> Envelope`

## Functional Requirements

- **FR-001**: The system shall map platform replies to the typed envelope.
            traces: PlatformEnvelope

## Lanes

```yaml
Lanes:
  - lane: SKIN
    behaviors: [A1, A2, U1]
    flutter_allowed: true
```
''';

/// The issue's refusal case: a kind no lane section renders (theme) must
/// refuse instead of dropping.
const String themeLanesSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the dark theme **When** the user enables dark mode **Then** the themed palette applies
   **Type**: theme

## Layer Contracts

**Function**:
- `PaletteApplier`: `apply(Palette) -> void`

## Functional Requirements

- **FR-001**: The system shall apply the themed palette.
            traces: PaletteApplier

## Lanes

```yaml
Lanes:
  - lane: SKIN
    behaviors: [A1, U1]
    flutter_allowed: true
```
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug_1432_platform_lane_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedSpec(String spec) =>
      File(p.join(featureDir, 'spec.md')).writeAsString(spec);

  List<String> planArgs() => ['tdd', 'plan', '--project', tmpDir.path, feature];

  File laneFile(String name) => File(p.join(tddDir, name));

  /// The behavior data-row ids of [md]: first cell of every table data row
  /// (id-shaped: letter-prefixed, the lane plans' row shape).
  Set<String> rowIds(String md) => RegExp(
    r'^\| ([A-Za-z][A-Za-z0-9-]*) \|',
    multiLine: true,
  ).allMatches(md).map((m) => m.group(1)!).where((id) => id != 'id').toSet();

  group('Bug #1432 — platform scenarios are first-class SKIN rows', () {
    test('plans exit 0 with the platform row in the SKIN acceptance table '
        '(A-1432-1)', () async {
      await seedSpec(platformLanesSpec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());

      expect(exitCode, 0, reason: 'plan succeeded — out:\n$out');
      expect(out, contains('route: A1 -> platform lane'));
      final skin = laneFile('04-SKIN.md').readAsStringSync();
      final acceptanceSection = skin
          .split('\n## ')
          .firstWhere(
            (s) => s.startsWith('Outer loop: acceptance behaviors'),
            orElse: () => '',
          );
      expect(
        acceptanceSection,
        isNotEmpty,
        reason:
            'the acceptance section renders (the fixture has an '
            'acceptance-typed row)',
      );
      expect(
        acceptanceSection,
        contains('| A1 |'),
        reason:
            'the platform-typed scenario routes to the SKIN lane, so its '
            'row must render in the outer-loop table — the log already '
            'claims it (issue #1432)',
      );
      expect(acceptanceSection, contains('| A2 |'));
    });

    test('the route log and the artifacts agree for every routed id '
        '(A-1432-2)', () async {
      await seedSpec(platformLanesSpec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());

      final routed = RegExp(
        r'route: (\S+) -> (\w+) lane',
        multiLine: true,
      ).allMatches(out).map((m) => (id: m.group(1)!, lane: m.group(2)!));
      expect(routed, isNotEmpty, reason: 'the fixture routes behaviors');
      final skinIds = rowIds(laneFile('04-SKIN.md').readAsStringSync());
      for (final (:id, lane: laneName) in routed) {
        if (laneName == 'contract') {
          // The contract lane's row rendering is open issue #1419 — out of
          // this fix's scope.
          continue;
        }
        expect(
          skinIds,
          contains(id),
          reason:
              'the log routed "$id" to the $laneName lane (fixture: all '
              'SKIN) — the artifact must carry the row (log ↔ artifact '
              'agreement, issue #1432)',
        );
      }
    });

    test('the meta-index declares exactly the rows the SKIN artifact '
        'carries, platform row counted (A-1432-4)', () async {
      await seedSpec(platformLanesSpec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());

      expect(exitCode, 0, reason: 'plan succeeded — out:\n$out');
      final meta = laneFile('test-list.md').readAsStringSync();
      final skinMetaRow = meta
          .split('\n')
          .firstWhere(
            (l) => l.toLowerCase().startsWith('| skin |'),
            orElse: () => '',
          );
      expect(skinMetaRow, isNotEmpty, reason: 'the meta-index declares SKIN');
      final declaredIds = skinMetaRow
          .split('|')[2]
          .trim()
          .split(', ')
          .map((s) => s.trim())
          .toSet();
      final skinIds = rowIds(laneFile('04-SKIN.md').readAsStringSync());
      expect(
        declaredIds,
        contains('A1'),
        reason: 'the platform row is declared because it is rendered',
      );
      expect(
        declaredIds,
        skinIds,
        reason:
            'the declared ids must equal the rows the artifact carries '
            '— declaring over dropped rows is the #1432 lie',
      );
    });
  });

  group('Bug #1432 — refuse kinds no lane section renders', () {
    test('a theme-typed scenario refuses instead of dropping '
        '(A-1432-3)', () async {
      await seedSpec(themeLanesSpec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());

      expect(
        exitCode,
        2,
        reason:
            'errors-are-an-API: a kind no lane section renders must '
            'refuse, not exit 0 with the row dropped — out:\n$out',
      );
      expect(out, contains('A1'));
      expect(out, contains('theme'));
      expect(
        laneFile('04-ENGINE.md').existsSync(),
        isFalse,
        reason: 'an incomplete split never leaves a half-written lane plan',
      );
      expect(laneFile('04-SKIN.md').existsSync(), isFalse);
      expect(laneFile('04-CONTRACT.md').existsSync(), isFalse);
    });
  });
}
