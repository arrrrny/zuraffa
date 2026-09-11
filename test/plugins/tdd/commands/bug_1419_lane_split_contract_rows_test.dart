// Bug #1419 — `zfa tdd plan`'s lane-split path silently drops the
// spec-derived Layer Contract behaviors: the route log claims them
// (`route: contract:A1 -> contract lane [declared: MessageTransport]`)
// while 04-ENGINE.md carries only the A/U rows — exit 0, no refusal, no
// coverage-gate failure. The legacy (no-Lanes) path renders the same
// rows, so a spec loses its declared method contracts the moment it
// declares lanes.
//
// Contract under test:
// 1. The derived contract rows land in the ENGINE plan's contract-loop
//    section with the legacy path's shape: derived description
//    (`Interface.method(...) -> Type (entity method contract)`),
//    `Interface.method` trace, contract kind, reconciled state.
// 2. The reader resolves them from the split artifacts with
//    contract kind — the BLOCKED semantics of spec 1007 survive the
//    split (a re-plan keeps a recorded BLOCKED state).
// 3. A `contract:A<n>` declaration in `## Lanes` joins the derived
//    behavior instead of clobbering it with the anonymous
//    "core behavior declared in `## Lanes`" hand row.
// 4. A contract id declared into a non-engine lane (SKIN) refuses —
//    honoring it would drop the row from the split plan again (the SKIN
//    plan renders no contract section; spec 1007: a contract test is
//    pure Dart, so it rides the engine).
// 5. The meta-index counts the contract ids in the CORE lane's resolved
//    list — the lane-coverage accounting sees them.
// 6. The #1309 stale-split regeneration (no `## Lanes`, a receipt)
//    writes the same engine-side contract rows the Lanes path does.
// 7. `zfa tdd split` — which calls the same engine renderer — migrates a
//    legacy list's contract row into 04-ENGINE.md instead of writing an
//    engine plan that contradicts its own meta-index and receipt.
//
// RED phase: recorded against the unfixed tree — the engine plan omits
// the contract section, the reader resolves no contract rows, the
// declared id renders the anonymous hand row, the SKIN declaration
// exits 0.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

const String feature = '004-login-ui';

/// The issue's shape: Layer Contracts (spec 1007) + Lanes (spec 1000),
/// the contract ids NOT declared in any lane — they must still land in
/// the engine plan (CORE by default).
const String contractLanesSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the transport **When** an outbound message is sent **Then** the message is delivered to the channel
   **Type**: acceptance
2. **Given** the transport **When** a delivered message is acknowledged **Then** the acknowledgment is recorded
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The system shall send outbound messages through the transport.
- **FR-002**: The system shall acknowledge delivered messages.

## Layer Contracts

**Entities**:
- `MessageTransport`: `send(OutboundMessage) -> Message`, `acknowledge(String) -> bool`

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, U1, U2]
    flutter_allowed: false
```
''';

/// The secondary symptom: the author declares the contract id in the
/// CORE lane — the declaration must JOIN the derived behavior, not
/// clobber it with the anonymous hand-row description.
const String declaredCoreContractSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the transport **When** an outbound message is sent **Then** the message is delivered to the channel
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The system shall send outbound messages through the transport.

## Layer Contracts

**Entities**:
- `MessageTransport`: `send(OutboundMessage) -> Message`, `acknowledge(String) -> bool`

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1, contract:A1, contract:A2]
    flutter_allowed: false
```
''';

/// The refusal case: a derived contract id declared into the SKIN lane
/// would drop from the split plan again (the SKIN plan renders no
/// contract section) — refuse instead.
const String declaredSkinContractSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the transport **When** an outbound message is sent **Then** the message is delivered to the channel
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The system shall send outbound messages through the transport.

## Layer Contracts

**Entities**:
- `MessageTransport`: `send(OutboundMessage) -> Message`, `acknowledge(String) -> bool`

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [contract:A1]
    flutter_allowed: true
```
''';

/// The engine purity case: a contract signature referencing the Flutter
/// package would land in 04-ENGINE.md, which is pure Dart by
/// construction — the noFlutter guard refuses.
const String flutterReferenceContractSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the transport **When** an outbound message is sent **Then** the message is delivered to the channel
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The system shall send outbound messages through the transport.

## Layer Contracts

**Entities**:
- `MessageTransport`: `send(package:flutter services) -> bool`

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1]
    flutter_allowed: false
```
''';

/// The #1309 stale-split shape: `## Layer Contracts` and NO `## Lanes`,
/// plus a `tdd/split-receipt.json` — `zfa tdd plan` regenerates the lane
/// plans through the split kind heuristic (`_heuristicLaneResolution`),
/// which must carry the derived contract rows too.
const String contractNoLanesSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the transport **When** an outbound message is sent **Then** the message is delivered to the channel
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The system shall send outbound messages through the transport.

## Layer Contracts

**Entities**:
- `MessageTransport`: `send(OutboundMessage) -> Message`
''';

/// A legacy single-file list whose rows the one-shot `zfa tdd split`
/// migrates — including the contract row the split's own meta-index and
/// receipt classify CORE.
const String legacyListWithContract =
    '''
# Test List: $feature

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the message is delivered to the channel | AC-1 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | sends outbound messages through the transport | FR-001 | PENDING |

## Contract loop: contract behaviors

One per declared entity method, controller method and usecase in
`spec.md` Layer Contracts (issue #1007).

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| contract:A1 | MessageTransport.send(OutboundMessage) -> Message (entity method contract) | MessageTransport.send | BLOCKED |
''';

/// A legacy single-file list carrying a BLOCKED contract row — the
/// recorded state the split plan must keep (spec 1007 BLOCKED
/// semantics survive the split).
const String priorBlockedList =
    '''
# Test List: $feature

## Contract loop: contract behaviors

One per declared entity method, controller method and usecase in
`spec.md` Layer Contracts (issue #1007).

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| contract:A1 | MessageTransport.send(OutboundMessage) -> Message (entity method contract) | MessageTransport.send | BLOCKED |
''';

/// The loop-section titles whose tables carry behavior rows — the
/// sections `rowIds` scopes its extraction to.
const List<String> _behaviorSectionTitles = [
  'Outer loop:',
  'Inner loop:',
  'Native loop:',
  'Contract loop:',
];

/// The concatenated bodies of [md]'s behavior sections. A `## ` heading
/// outside [_behaviorSectionTitles] (`## Key entities`,
/// `## External dependencies`, `## Layer contracts`,
/// `## Routing provenance`) carries declarations, not behaviors.
String _behaviorSections(String md) {
  final buf = StringBuffer();
  var inBehaviorSection = false;
  for (final line in md.split('\n')) {
    if (line.startsWith('## ')) {
      final title = line.substring(3);
      inBehaviorSection = _behaviorSectionTitles.any(title.startsWith);
    }
    if (inBehaviorSection) buf.writeln(line);
  }
  return buf.toString();
}

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug_1419_contract_lanes_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedSpec(String spec) =>
      File(p.join(featureDir, 'spec.md')).writeAsString(spec);

  List<String> planArgs() => [
    'tdd',
    'plan',
    '--project',
    tmpDir.path,
    feature,
    // Issue #1480: derived contract rows are intentionally planned
    // through the legacy fallback shape.
    '--allow-unit-fallback',
  ];

  File laneFile(String name) => File(p.join(tddDir, name));

  /// The behavior data-row ids of [md]: first cell of every table data
  /// row inside the BEHAVIOR sections (the `contract:A<n>` ids carry a
  /// colon). The declaration tables (`## Key entities`,
  /// `## External dependencies`, `## Layer contracts`) are skipped —
  /// their headers (`entity`, `dependency`) are not behaviors, and
  /// counting them would turn this fixture red the moment the spec
  /// grows a declaration section (a change unrelated to the contract
  /// under test).
  Set<String> rowIds(String md) =>
      RegExp(r'^\| ([A-Za-z][A-Za-z0-9:-]*) \|', multiLine: true)
          .allMatches(_behaviorSections(md))
          .map((m) => m.group(1)!)
          .where((id) => id != 'id')
          .toSet();

  group('Bug #1419 — derived contract rows land in the engine plan', () {
    test('the engine plan carries the contract-loop section with the '
        'derived rows (A-1419-1)', () async {
      await seedSpec(contractLanesSpec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());

      expect(exitCode, 0, reason: 'plan succeeded — out:\n$out');
      expect(
        out,
        contains('route: contract:A1 -> contract lane'),
        reason: 'the route log already claims the derived contract rows',
      );
      final engine = laneFile('04-ENGINE.md').readAsStringSync();
      final contractSection = engine
          .split('\n## ')
          .firstWhere(
            (s) => s.startsWith('Contract loop: contract behaviors'),
            orElse: () => '',
          );
      expect(
        contractSection,
        isNotEmpty,
        reason:
            'the derived contract behaviors must reach the engine plan '
            'the legacy single-file path renders — the silent drop is '
            'the bug (issue #1419)',
      );
      expect(
        contractSection,
        contains(
          '| contract:A1 | MessageTransport.send(OutboundMessage) -> '
          'Message (entity method contract) | MessageTransport.send | '
          'PENDING |',
        ),
        reason:
            'the send contract row keeps the derived description, '
            'Interface.method trace, and contract-loop state',
      );
      expect(
        contractSection,
        contains(
          '| contract:A2 | MessageTransport.acknowledge(String) -> bool '
          '(entity method contract) | MessageTransport.acknowledge | '
          'PENDING |',
        ),
      );
    });

    test('the reader resolves the contract rows from the split artifacts '
        'with contract kind (A-1419-2)', () async {
      await seedSpec(contractLanesSpec);
      await CliRunner(exitOnCompletion: false).runCapturing(planArgs());

      final rows = await TestListReader(featureDir).read();
      final contracts = rows
          .where((r) => r.id.startsWith('contract:'))
          .toList();
      expect(
        contracts.map((r) => r.id),
        containsAll(<String>['contract:A1', 'contract:A2']),
        reason:
            'gen/make/run/verify resolve the plan through this reader — '
            'no contract rows means the declared contracts vanish from '
            'the whole loop (issue #1419)',
      );
      for (final row in contracts) {
        expect(
          row.kind,
          BehaviorKind.contract,
          reason:
              'the contract kind carries the spec-1007 BLOCKED '
              'semantics — a unit-kind downgrade loses them',
        );
      }
    });

    test('the meta-index counts the contract ids in the CORE lane '
        '(A-1419-3)', () async {
      await seedSpec(contractLanesSpec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());

      expect(exitCode, 0, reason: 'plan succeeded — out:\n$out');
      final meta = laneFile('test-list.md').readAsStringSync();
      final coreMetaRow = meta
          .split('\n')
          .firstWhere(
            (l) => l.toLowerCase().startsWith('| core |'),
            orElse: () => '',
          );
      expect(coreMetaRow, isNotEmpty, reason: 'the meta-index declares CORE');
      expect(
        coreMetaRow,
        contains('contract:A1'),
        reason:
            'the lane-coverage accounting must count the derived '
            'contract behaviors — their absence is why nothing caught '
            'the drop (issue #1419)',
      );
      expect(coreMetaRow, contains('contract:A2'));
      final declaredIds = coreMetaRow
          .split('|')[2]
          .trim()
          .split(', ')
          .map((s) => s.trim())
          .toSet();
      final engineIds = rowIds(laneFile('04-ENGINE.md').readAsStringSync());
      expect(
        declaredIds,
        engineIds,
        reason:
            'the declared ids must equal the rows the artifact '
            'carries — declaring over dropped rows is the silent-drop '
            'lie',
      );
    });
  });

  group('Bug #1419 — declared contract ids join the derived behavior', () {
    test('a CORE declaration keeps the derived description, trace and '
        'contract kind — no anonymous clobber row (A-1419-4)', () async {
      await seedSpec(declaredCoreContractSpec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());

      expect(exitCode, 0, reason: 'plan succeeded — out:\n$out');
      final engine = laneFile('04-ENGINE.md').readAsStringSync();
      expect(
        engine,
        contains('MessageTransport.send(OutboundMessage) -> Message'),
        reason:
            'the declaration joins the derived behavior — the '
            'derived description wins',
      );
      expect(
        engine,
        isNot(contains('core behavior declared in `## Lanes`')),
        reason:
            'the anonymous hand-row description clobbered the '
            'derived one pre-fix (issue #1419 secondary symptom)',
      );
      expect(
        engine,
        isNot(contains('| LANE:CORE |')),
        reason:
            'the anonymous hand-row trace clobbered the '
            'Interface.method trace pre-fix',
      );
      final rows = await TestListReader(featureDir).read();
      final declared = rows.firstWhere((r) => r.id == 'contract:A1');
      expect(
        declared.kind,
        BehaviorKind.contract,
        reason: 'the declared contract id keeps the contract kind',
      );
      expect(declared.traces, 'MessageTransport.send');
    });
  });

  group('Bug #1419 — non-engine declarations refuse', () {
    test('a SKIN-declared contract id refuses instead of dropping '
        '(A-1419-5)', () async {
      await seedSpec(declaredSkinContractSpec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());

      expect(
        exitCode,
        2,
        reason:
            'errors-are-an-API: the SKIN plan renders no contract '
            'section, so honoring the declaration would drop the row '
            'from the split plan again — out:\n$out',
      );
      expect(out, contains('contract:A1'));
      expect(
        laneFile('04-ENGINE.md').existsSync(),
        isFalse,
        reason: 'an incomplete split never leaves a half-written lane plan',
      );
      expect(laneFile('04-SKIN.md').existsSync(), isFalse);
    });

    test('a contract signature referencing the Flutter package refuses — '
        'the engine lane is pure Dart (A-1419-7)', () async {
      await seedSpec(flutterReferenceContractSpec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());

      expect(
        exitCode,
        2,
        reason:
            'the contract rows land in 04-ENGINE.md, which is pure Dart '
            'by construction — a signature referencing the Flutter '
            'package must refuse at plan time — out:\n$out',
      );
      expect(out, contains('noFlutter guard'));
      expect(out, contains('contract:A1'));
      expect(laneFile('04-ENGINE.md').existsSync(), isFalse);
    });
  });

  group('Bug #1419 — BLOCKED semantics survive the split', () {
    test('a recorded BLOCKED contract state re-plans BLOCKED into the '
        'engine plan (A-1419-6)', () async {
      await seedSpec(contractLanesSpec);
      await laneFile('test-list.md').writeAsString(priorBlockedList);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());

      expect(exitCode, 0, reason: 'plan succeeded — out:\n$out');
      final engine = laneFile('04-ENGINE.md').readAsStringSync();
      expect(
        engine,
        contains(
          '| contract:A1 | MessageTransport.send(OutboundMessage) -> '
          'Message (entity method contract) | MessageTransport.send | '
          'BLOCKED |',
        ),
        reason:
            'the reconcile keeps the recorded state — a failing '
            'contract test is BLOCKED (never RED), and the split plan '
            'must carry the same semantics the legacy path wrote',
      );
    });
  });

  group('Bug #1419 — the stale-split regeneration carries the contract '
      'rows', () {
    test('a receipt-bearing feature with no `## Lanes` regenerates the '
        'contract rows into the engine plan (A-1419-8)', () async {
      await seedSpec(contractNoLanesSpec);
      await laneFile('split-receipt.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'feature': feature,
          'split_at': '2026-09-10T00:00:00.000Z',
          'source': 'tdd/test-list.md',
          'rows': 3,
        }),
      );
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());

      expect(exitCode, 0, reason: 'plan succeeded — out:\n$out');
      final engine = laneFile('04-ENGINE.md').readAsStringSync();
      expect(
        engine,
        contains(
          '| contract:A1 | MessageTransport.send(OutboundMessage) -> '
          'Message (entity method contract) | MessageTransport.send | '
          'PENDING |',
        ),
        reason:
            'the split kind heuristic (`_heuristicLaneResolution`, the '
            'issue #1309 regeneration) writes the same engine-side '
            'contract rows the declared-Lanes path does',
      );
      final meta = laneFile('test-list.md').readAsStringSync();
      final coreMetaRow = meta
          .split('\n')
          .firstWhere(
            (l) => l.toLowerCase().startsWith('| core |'),
            orElse: () => '',
          );
      expect(
        coreMetaRow,
        contains('contract:A1'),
        reason:
            'the regenerated meta-index counts the contract id in CORE — '
            'declaring over a dropped row is the silent-drop lie',
      );
    });
  });

  group('Bug #1419 — the shared renderer closes the `zfa tdd split` '
      'path', () {
    test('a migrated legacy list keeps its contract row in the engine '
        'plan (A-1419-9)', () async {
      await seedSpec(contractLanesSpec);
      await laneFile('test-list.md').writeAsString(legacyListWithContract);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'split', '--project', tmpDir.path, feature]);

      expect(exitCode, 0, reason: 'split succeeded — out:\n$out');
      final engine = laneFile('04-ENGINE.md').readAsStringSync();
      expect(
        engine,
        contains(
          '| contract:A1 | MessageTransport.send(OutboundMessage) -> '
          'Message (entity method contract) | MessageTransport.send | '
          'BLOCKED |',
        ),
        reason:
            '`zfa tdd split` calls the same engine renderer as plan — a '
            'caller-side contract section left this path writing an '
            'engine plan that omitted the row its own meta-index and '
            'receipt classified',
      );
      final meta = laneFile('test-list.md').readAsStringSync();
      final coreMetaRow = meta
          .split('\n')
          .firstWhere(
            (l) => l.toLowerCase().startsWith('| core |'),
            orElse: () => '',
          );
      expect(
        coreMetaRow,
        contains('contract:A1'),
        reason: 'the meta-index declares the row the artifact must carry',
      );
    });
  });
}
