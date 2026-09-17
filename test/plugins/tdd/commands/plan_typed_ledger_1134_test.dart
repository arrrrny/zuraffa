// EPIC 3 / issue #1134, lane 3 — `zfa tdd plan` derives and writes the
// TYPED UI coverage ledger (merging #963's surface ledger with #966's
// typed rows): `tdd/typed-ledger.md` + `tdd/typed-ledger.json`, every
// row (surface, kind: presence|absence|navigation|state|sequence,
// status: traced|untraced); a feature declaring `adaptive_layouts`
// additionally carries the per-layout kind-coverage heatmap (exit
// criterion 2's artifact). The 075 `ui-ledger.{md,json}` pair keeps
// its pinned shape — the typed ledger is a NEW artifact pair.
//
//  U-1134-t3: plan writes the typed ledger artifact pair; every row
//             carries a five-kind kind + a traced|untraced status;
//             plan-time rows are untraced, visible, never omitted.
//  U-1134-t6: a feature declaring `adaptive_layouts: mobile, macos`
//             gets the per-layout heatmap section + platform rows in
//             the JSON.
//  U-1134-t9: the 075 ui-ledger.{md,json} artifacts keep their pinned
//             shape (zero drift on the legacy artifacts).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const feature = '004-login-typed';

const specWithSlots = '''
**Template Version**: `zuraffa-1.0`

# Feature Specification: $feature — the adaptive login skin

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
   **Type**: acceptance

2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller
   **Type**: acceptance

3. **Given** the login view **When** it renders **Then** the app shows 'Sign in'
   **Type**: widget

4. **Given** a completed sign-in **When** the user signs in **Then** the app navigates to the route 'deal_list'
   **Type**: widget

5. **Given** a fresh login view **When** no sign-in attempt has failed **Then** the 'Sign in failed' banner is not shown
   **Type**: widget

6. **Given** an empty form **When** validation runs **Then** the 'Sign in' button is disabled
   **Type**: widget

7. **Given** a submitted form **Then** while the sign-in request is in flight the app shows 'Signing in…' and then the app navigates to the route 'deal_list'
   **Type**: widget

## Functional Requirements

- **FR-001**: The system shall present the adaptive login view with the declared platform slots (mobile, macos).
      traces: adaptive_layouts

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [U1, A3, A4, A5, A6, A7]
    flutter_allowed: true
    adaptive_slots: [mobile, macos]
```

## Layer Contracts

**Presentation**:

- `LoginForm`: `ShadInput` for email and password, `ShadButton` for Sign In
- `adaptive_layouts`: `mobile`, `macos`

**Domain**:

- `LoginValidation`: `isSubmittable(String email, String password) -> bool`
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('plan_typed_ledger_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  Future<String> plan() => CliRunner(exitOnCompletion: false).runCapturing(
        ['tdd', 'plan', '--project', tmpDir.path, feature],
      );

  test('U-1134-t3: plan writes the typed ledger artifact pair with '
      'five-kind rows and traced|untraced status (plan-time untraced)', () async {
    await File(p.join(featureDir, 'spec.md')).writeAsString(specWithSlots);
    final out = await plan();

    expect(exitCode, 0, reason: out);
    final typedMd = File(p.join(tddDir, 'typed-ledger.md'));
    final typedJson = File(p.join(tddDir, 'typed-ledger.json'));
    expect(typedMd.existsSync(), isTrue, reason: 'the typed ledger markdown');
    expect(typedJson.existsSync(), isTrue, reason: 'the typed ledger JSON');
    expect(
      out,
      contains('typed-ledger.md'),
      reason: 'the plan reports the artifact it wrote',
    );

    final md = await typedMd.readAsString();
    // The typed table: surface | kind | proven by | state | semantics.
    expect(md, contains('# Typed Coverage Ledger'));
    expect(md, contains('| presence |'));
    expect(md, contains('| absence |'));
    expect(md, contains('| navigation |'));
    expect(md, contains('| state |'));
    expect(md, contains('| sequence |'));
    // Plan-time rows are untraced (NOT-DONE), visible, never omitted.
    expect(md, contains('NOT-DONE'));
    // The declared component tokens are presence rows.
    expect(md, contains('ShadInput'));

    final json = jsonDecode(await typedJson.readAsString()) as List<dynamic>;
    expect(json, isNotEmpty);
    final kinds = json
        .map((r) => (r as Map<String, dynamic>)['kind'] as String?)
        .toSet();
    expect(
      kinds,
      containsAll([
        'presence',
        'absence',
        'navigation',
        'state',
        'sequence',
      ]),
      reason: 'the five-kind vocabulary rides every row',
    );
    // The epic's status vocabulary: traced|untraced (plan-time:
    // untraced — state recomputes at read time, a stored state is a
    // cache).
    final statuses = json
        .map((r) => (r as Map<String, dynamic>)['status'] as String?)
        .toSet();
    expect(statuses, {'untraced'});
  });

  test('U-1134-t6: adaptive_layouts declares the per-layout heatmap '
      'section + platform rows in the JSON', () async {
    await File(p.join(featureDir, 'spec.md')).writeAsString(specWithSlots);
    final out = await plan();

    expect(exitCode, 0, reason: out);
    final md = await File(p.join(tddDir, 'typed-ledger.md')).readAsString();
    // The per-layout kind-coverage heatmap: kind rows × slot columns.
    expect(md, contains('## Per-layout kind coverage heatmap'));
    expect(md, contains('| kind | mobile | macos |'));
    expect(md, contains('presence'));
    expect(md, contains('navigation'));

    final json = jsonDecode(
      await File(p.join(tddDir, 'typed-ledger.json')).readAsString(),
    ) as List<dynamic>;
    // The platform rows ride the same JSON: slot + kind + status.
    final platformRows = json
        .map((r) => r as Map<String, dynamic>)
        .where((r) => r.containsKey('slot'))
        .toList();
    expect(platformRows, isNotEmpty);
    expect(
      platformRows.every((r) => r['status'] == 'untraced'),
      isTrue,
      reason: 'plan-time: no SkinEvent evidence yet — every per-slot row '
          'untraced, visible, never omitted',
    );
    final slots = platformRows.map((r) => r['slot']).toSet();
    expect(slots, {'mobile', 'macos'});
  });

  test('U-1134-t9: the 075 ui-ledger.{md,json} artifacts keep their '
      'pinned shape (the typed pair is additive — zero drift)', () async {
    await File(p.join(featureDir, 'spec.md')).writeAsString(specWithSlots);
    final out = await plan();

    expect(exitCode, 0, reason: out);
    final legacyMd = await File(p.join(tddDir, 'ui-ledger.md')).readAsString();
    // The 075 shape: the surface ledger table + the #1142 platform
    // section — unchanged by the typed pair.
    expect(legacyMd, contains('# UI Surface Ledger'));
    expect(legacyMd, contains('| surface | kind | proven by | state |'));
    expect(legacyMd, contains('# Platform Coverage Ledger'));
    expect(legacyMd, contains('| slot | surface | kind | proven by | state |'));
    // The legacy kinds (text/route/affordance/key), NOT the typed
    // vocabulary — the pinned 075 shape.
    expect(legacyMd, contains('| affordance |'));
    expect(legacyMd, isNot(contains('| sequence |')));

    final legacyJson = jsonDecode(
      await File(p.join(tddDir, 'ui-ledger.json')).readAsString(),
    ) as List<dynamic>;
    // Legacy rows keep their fields; platform rows keep slot+state
    // (DONE/NOT-DONE), never the typed status vocabulary.
    final platformRows = legacyJson
        .map((r) => r as Map<String, dynamic>)
        .where((r) => r.containsKey('slot'))
        .toList();
    expect(platformRows, isNotEmpty);
    expect(
      platformRows.every((r) => r['state'] == 'NOT-DONE'),
      isTrue,
      reason: 'the #1142 per-platform rows keep their pinned state '
          'vocabulary',
    );
  });
}
