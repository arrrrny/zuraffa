// Bug #1480 (fix lever 1) — the spec↔contract mapping is decoupled from
// spec.md: `zfa tdd plan` reads contract rows and FR traces from the
// feature's `contracts/*.md` files (the contracts directory the planning
// phase already writes) in addition to spec.md, so a spec-kit-authored
// spec WITHOUT inline zuraffa grammar resolves its unit lane as DECLARED
// instead of dead-ending the unit lane at make (vacuous-green).
//
// Fix contract:
//   - rows from contracts/*.md merge with spec.md rows (a colliding row
//     name resolves to the CONTRACT-FILE row — issue #1485's collision
//     policy, the shared helper every command-side consumer builds)
//   - criterion-keyed traces (`- **FR-001**: traces: Row`) bind by FR id,
//     filling behaviors with no inline spec trace
//   - an FR traced from BOTH spec.md (inline traces:) and a contracts
//     file REFUSES (double declaration)
//   - an FR traced from more than one contracts file REFUSES
//   - a criterion trace naming an unknown FR WARNS (parity with #1319)
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const _grammarlessSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1480-decoupled

## Functional Requirements

- **FR-001**: the system formats the user's template into a rendered string
- **FR-002**: the system persists the rendered result

## Acceptance Scenarios

1. **Given** a rendered template **When** the user opens the page **Then** the
   rendered content is shown.
   **Type**: acceptance
''';

const _contractsFile = '''
# Contract: rendering seam (held beside the spec, issue #1480)

## Layer Contracts

**Function**:
- `Formatter`: `format(Template) -> String`

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| RenderedResult | `text: String` | The rendered output the loop persists |

## Contract Traces

- **FR-001**: traces: Formatter.format
- **FR-002**: traces: RenderedResult
''';

Future<(Directory, String)> _feature(String spec, {String? contracts}) async {
  final tmp = Directory.systemTemp.createTempSync('decoupled1480_');
  final featureDir = p.join(tmp.path, 'specs', '1480-decoupled');
  await Directory(featureDir).create(recursive: true);
  await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
  if (contracts != null) {
    final contractsDir = Directory(p.join(featureDir, 'contracts'));
    await contractsDir.create(recursive: true);
    await File(
      p.join(contractsDir.path, 'layer-contracts.md'),
    ).writeAsString(contracts);
  }
  return (tmp, featureDir);
}

Future<String> _plan(Directory tmp, [List<String> extra = const []]) async {
  final runner = CliRunner(exitOnCompletion: false);
  final out = await runner.runCapturing([
    'tdd',
    'plan',
    '1480-decoupled',
    '--project',
    tmp.path,
    ...extra,
  ]);
  return out;
}

void main() {
  late Directory tmpDir;
  late String featureDir;

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    CliRunner.lastDispatchedExitCode = 0;
  });

  group('bug #1480 — the mapping may live in contracts/*.md', () {
    test('U1+A1: a grammarless spec + a contracts file plans DECLARED '
        '(unit lane routes by the declared contract row, exit 0)', () async {
      (tmpDir, featureDir) = await _feature(
        _grammarlessSpec,
        contracts: _contractsFile,
      );

      final out = await _plan(tmpDir);

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason:
            'the declared mapping lives beside the spec — the plan must '
            'resolve it (issue #1480): out was\n$out',
      );
      final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
      expect(testList.existsSync(), isTrue, reason: out);
      final routing = testList.readAsStringSync();
      expect(
        routing,
        contains('[declared: contract row: Formatter'),
        reason:
            'U1 must route by the contract row declared in the contracts '
            'file — not the legacy fallback; routing was\n$routing',
      );
      expect(routing, isNot(contains('[fallback:')));
    });

    test('U1b: a criterion trace naming an UNKNOWN FR warns and the plan '
        'still proceeds (parity with the #1319 unbound warning)', () async {
      (tmpDir, featureDir) = await _feature(
        _grammarlessSpec,
        contracts: _contractsFile.replaceFirst(
          '- **FR-001**: traces: Formatter.format',
          '- **FR-001**: traces: Formatter.format\n'
              '- **FR-999**: traces: Formatter.format',
        ),
      );

      final out = await _plan(tmpDir);

      expect(
        out,
        contains('FR-999'),
        reason: 'the unknown criterion trace is warned about (not silent)',
      );
      expect(
        containsIgnoringCase(out, 'warning'),
        isTrue,
        reason: 'the message is a warning, not a refusal: out was\n$out',
      );
      final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
      expect(
        testList.existsSync(),
        isTrue,
        reason: 'a warning never blocks the plan',
      );
    });

    test('U5a: a contract row declared in BOTH spec.md and the contracts '
        'file resolves to the CONTRACT-FILE row (issue #1485 collision '
        'policy — the shared merge helper every command consumes)', () async {
      final bothRows = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1480-decoupled

## Layer Contracts

**Function**:
- `Formatter`: `format(Template) -> String`

## Functional Requirements

- **FR-001**: the system formats the user's template

## Acceptance Scenarios

1. **Given** a template **When** it renders **Then** the string returns.
   **Type**: acceptance
''';
      // The discriminating method: spec.md declares `format`, the
      // contracts file declares `render` for the same row name. The
      // routing cell proves WHICH source won the collision.
      final overridingContracts = _contractsFile
          .replaceFirst(
            '- `Formatter`: `format(Template) -> String`',
            '- `Formatter`: `render(Template) -> String`',
          )
          .replaceFirst(
            '- **FR-001**: traces: Formatter.format',
            '- **FR-001**: traces: Formatter.render',
          );
      (tmpDir, featureDir) = await _feature(
        bothRows,
        contracts: overridingContracts,
      );

      final out = await _plan(tmpDir);

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason:
            'a colliding name resolves to the contract-file row and '
            'the plan proceeds (issue #1485): out was\n$out',
      );
      final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
      expect(testList.existsSync(), isTrue, reason: out);
      final routing = testList.readAsStringSync();
      // The unit row's traces cell is the discriminator: spec.md declared
      // `Formatter.format`, the contracts file declared `Formatter.render`
      // — #1485's collision policy puts the CONTRACT-FILE row in the cell.
      // (The derived contract behavior further below legitimately carries
      // spec.md's `Formatter.format` — it derives from the spec's
      // `## Layer Contracts` prose, not the declared-rows merge.)
      final u1Line = routing
          .split('\n')
          .firstWhere((line) => line.startsWith('| U1 |'));
      expect(
        u1Line,
        contains('Formatter.render'),
        reason:
            'the CONTRACT-FILE row (render) won the collision — '
            'the U1 row was\n$u1Line',
      );
      expect(
        u1Line,
        isNot(contains('Formatter.format')),
        reason:
            'the spec.md row never surfaces in the U1 row once the '
            'contract-file row wins',
      );
    });

    test('U5b: an FR traced from BOTH spec.md and the contracts file refuses '
        'naming both (double declaration)', () async {
      final inlineTraced = _grammarlessSpec.replaceFirst(
        '- **FR-001**: the system formats the user\'s template into a rendered string',
        '- **FR-001**: the system formats the user\'s template into a rendered string\n'
            '            traces: SomethingElse',
      );
      (tmpDir, featureDir) = await _feature(
        inlineTraced,
        contracts: _contractsFile,
      );

      final out = await _plan(tmpDir);

      expect(
        CliRunner.lastDispatchedExitCode,
        2,
        reason: 'a double-declared trace refuses (exit 2): out was\n$out',
      );
      expect(out, contains('FR-001'));
      final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
      expect(
        testList.existsSync(),
        isFalse,
        reason: 'a refused plan writes no artifacts',
      );
    });
  });
}

bool containsIgnoringCase(String haystack, String needle) =>
    haystack.toLowerCase().contains(needle.toLowerCase());
